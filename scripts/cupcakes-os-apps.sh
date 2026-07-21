#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
catalog_lib="${CUPCAKES_OS_APP_CATALOG_LIB:-$script_dir/cupcakes-os-app-catalog.sh}"
ui_lib="${CUPCAKES_OS_UI_LIB:-$script_dir/cupcakes-os-ui.sh}"

if [[ ! -f "$catalog_lib" && -f /etc/cupcakes-os/app-catalog.sh ]]; then
    catalog_lib="/etc/cupcakes-os/app-catalog.sh"
fi

if [[ ! -f "$ui_lib" && -f /etc/cupcakes-os/ui.sh ]]; then
    ui_lib="/etc/cupcakes-os/ui.sh"
fi

# shellcheck source=/dev/null
source "$catalog_lib"
# shellcheck source=/dev/null
source "$ui_lib"

config_dir="${CUPCAKES_OS_SYSTEM_CONFIG:-/etc/nixos}"
cupcakes_os_dir="${config_dir}/cupcakes-os"
apps_list="${cupcakes_os_dir}/apps.list"
apps_module="${cupcakes_os_dir}/apps.nix"
flake_target="${CUPCAKES_OS_FLAKE_CONFIG_NAME:-cupcakes-os}"
default_repo_ref="${CUPCAKES_OS_REPO_REF:-main}"

usage() {
    cupcakes_os_banner "App Manager" "Install and remove apps on your Cupcakes OS system."
    printf '  %bUsage%b\n\n' "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC"
    printf '  %bcupcakes-os-apps catalog%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Browse all available apps by category."
    printf '\n'
    printf '  %bcupcakes-os-apps search <term>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Search apps by name, ID, or description."
    printf '\n'
    printf '  %bcupcakes-os-apps info <app-id>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Show details about a specific app."
    printf '\n'
    printf '  %bcupcakes-os-apps installed%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  List apps currently installed on this system."
    printf '\n'
    printf '  %bcupcakes-os-apps add <app-id...> [--no-rebuild] [--dry-run]%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Add one or more apps (rebuilds unless --no-rebuild is given)."
    printf '\n'
    printf '  %bcupcakes-os-apps remove <app-id...> [--no-rebuild] [--dry-run]%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Remove one or more apps (rebuilds unless --no-rebuild is given)."
    printf '\n'
    printf '  %bcupcakes-os-apps set [app-id...] [--no-rebuild] [--dry-run]%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Replace the full app list."
    printf '\n'
    printf '  %bcupcakes-os-apps bundle <name> [--no-rebuild] [--dry-run]%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Add a curated bundle: favorites essentials social creator developer gaming system"
    printf '\n'
    printf '  %bcupcakes-os-apps rebuild%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Apply the current app list (nixos-rebuild switch)."
    printf '\n'
}

is_installed_system() {
    [[ -d "$cupcakes_os_dir" && -f "$config_dir/flake.nix" ]]
}

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
        return 0
    fi

    if command -v sudo >/dev/null 2>&1; then
        sudo "$@"
        return 0
    fi

    cupcakes_os_error "This command needs root privileges."
    exit 1
}

ensure_layout() {
    if ! is_installed_system; then
        cupcakes_os_error "App installs work on an installed Cupcakes OS system, not the live image."
        exit 1
    fi

    run_as_root mkdir -p "$cupcakes_os_dir"

    if [[ ! -f "$apps_list" ]]; then
        run_as_root touch "$apps_list"
        run_as_root chmod 644 "$apps_list"
    fi

    if [[ ! -f "$apps_module" ]]; then
        render_apps_module
    fi
}

read_selected_ids() {
    if [[ ! -f "$apps_list" ]]; then
        return 0
    fi
    grep -v '^[[:space:]]*$' "$apps_list" 2>/dev/null | grep -v '^[[:space:]]*#' || true
}

write_selected_ids() {
    local tmp
    tmp="$(mktemp)"
    chmod 644 "$tmp"
    printf '%s\n' "$@" | awk 'NF && !seen[$0]++' > "$tmp"
    run_as_root mv "$tmp" "$apps_list"
}

render_apps_module() {
    local tmp app_id app_expr
    tmp="$(mktemp)"
    chmod 644 "$tmp"
    {
        printf '{ pkgs, ... }:\n'
        printf '{\n'
        printf '  environment.systemPackages = with pkgs; [\n'
        while IFS= read -r app_id; do
            [[ -n "$app_id" ]] || continue
            app_expr="$(cupcakes_os_catalog_expr "$app_id")" || continue
            printf '    %s\n' "$app_expr"
        done < <(read_selected_ids)
        printf '  ];\n'
        printf '}\n'
    } > "$tmp"
    run_as_root mv "$tmp" "$apps_module"
}

rebuild_system() {
    cupcakes_os_step "Rebuilding Cupcakes OS with the updated app selection"
    printf '\n'
    run_as_root nixos-rebuild switch --flake "${config_dir}#${flake_target}"
}

validate_ids() {
    local app_id
    for app_id in "$@"; do
        if ! cupcakes_os_catalog_has_app "$app_id"; then
            cupcakes_os_error "Unknown app id: $app_id"
            exit 1
        fi
    done
}

validate_bundle() {
    local bundle="$1"
    if ! cupcakes_os_catalog_bundle_ids "$bundle" >/dev/null 2>&1; then
        cupcakes_os_error "Unknown bundle: $bundle"
        cupcakes_os_dim_line "Valid bundles: favorites, essentials, social, creator, developer, gaming, system"
        exit 1
    fi
}

# ── Catalog display ───────────────────────────────────────────────────────────

show_catalog() {
    local app_id app_name app_expr app_group app_description app_favorite
    local current_group="" total=0 cols name_width desc_width

    cols="$(cupcakes_os_cols)"
    name_width=18
    desc_width=$((cols - name_width - 22))
    [[ $desc_width -lt 20 ]] && desc_width=20

    while IFS='|' read -r app_id app_name app_expr app_group app_description app_favorite; do
        total=$((total + 1))
    done < <(cupcakes_os_app_catalog)

    cupcakes_os_banner "App Catalog" "${total} apps available — run 'cupcakes-os-apps add <id>' to install."

    while IFS='|' read -r app_id app_name app_expr app_group app_description app_favorite; do
        if [[ "$app_group" != "$current_group" ]]; then
            [[ -n "$current_group" ]] && printf '\n'
            current_group="$app_group"
            printf '  %b%s%b\n' "$CUPCAKES_OS_WHITE" "${app_group^^}" "$CUPCAKES_OS_NC"
            cupcakes_os_rule
        fi

        local id_col name_col desc_col
        id_col="$(cupcakes_os_trunc "$app_id" 14)"
        name_col="$(cupcakes_os_trunc "$app_name" "$name_width")"
        desc_col="$(cupcakes_os_trunc "$app_description" "$desc_width")"

        printf '  %b·%b  %-14s  %b%-*s%b  %b%s%b' \
            "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" \
            "$id_col" \
            "$CUPCAKES_OS_DIM" "$name_width" "$name_col" "$CUPCAKES_OS_NC" \
            "$CUPCAKES_OS_FAINT" "$desc_col" "$CUPCAKES_OS_NC"

        if [[ "$app_favorite" == "yes" ]]; then
            printf '  %b★%b' "$CUPCAKES_OS_YELLOW" "$CUPCAKES_OS_NC"
        fi

        printf '\n'
    done < <(cupcakes_os_app_catalog)

    printf '\n'
}

# ── Search ────────────────────────────────────────────────────────────────────

search_apps() {
    local term="${1,,}"
    local app_id app_name app_expr app_group app_description app_favorite
    local cols name_width desc_width count=0

    cols="$(cupcakes_os_cols)"
    name_width=18
    desc_width=$((cols - name_width - 22))
    [[ $desc_width -lt 20 ]] && desc_width=20

    while IFS='|' read -r app_id app_name app_expr app_group app_description app_favorite; do
        local haystack="${app_id,,}|${app_name,,}|${app_description,,}"
        [[ "$haystack" == *"$term"* ]] || continue
        count=$((count + 1))

        local id_col name_col desc_col
        id_col="$(cupcakes_os_trunc "$app_id" 14)"
        name_col="$(cupcakes_os_trunc "$app_name" "$name_width")"
        desc_col="$(cupcakes_os_trunc "$app_description" "$desc_width")"

        printf '  %b·%b  %-14s  %b%-*s%b  %b%s%b' \
            "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" \
            "$id_col" \
            "$CUPCAKES_OS_DIM" "$name_width" "$name_col" "$CUPCAKES_OS_NC" \
            "$CUPCAKES_OS_FAINT" "$desc_col" "$CUPCAKES_OS_NC"

        if [[ "$app_favorite" == "yes" ]]; then
            printf '  %b★%b' "$CUPCAKES_OS_YELLOW" "$CUPCAKES_OS_NC"
        fi
        printf '\n'
    done < <(cupcakes_os_app_catalog)

    if [[ "$count" -eq 0 ]]; then
        cupcakes_os_warn "No apps matched '${1}'."
    else
        printf '\n  %b%d result(s)%b\n' "$CUPCAKES_OS_DIM" "$count" "$CUPCAKES_OS_NC"
    fi
    printf '\n'
}

# ── Info ──────────────────────────────────────────────────────────────────────

show_info() {
    local app_id="$1"
    local record app_name app_expr app_group app_description app_favorite

    if ! record="$(cupcakes_os_catalog_entry "$app_id")"; then
        cupcakes_os_error "Unknown app: $app_id"
        exit 1
    fi

    IFS='|' read -r _ app_name app_expr app_group app_description app_favorite <<< "$record"

    local status="${CUPCAKES_OS_DIM}not installed${CUPCAKES_OS_NC}"
    local id
    while IFS= read -r id; do
        if [[ "$id" == "$app_id" ]]; then
            status="${CUPCAKES_OS_GREEN}installed${CUPCAKES_OS_NC}"
            break
        fi
    done < <(read_selected_ids 2>/dev/null || true)

    cupcakes_os_banner "App Info" "$app_name"
    printf '  %bID%b           %s\n'  "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC" "$app_id"
    printf '  %bName%b         %s\n'  "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC" "$app_name"
    printf '  %bCategory%b     %s\n'  "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC" "$app_group"
    printf '  %bNix package%b  %s\n'  "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC" "$app_expr"
    printf '  %bStatus%b       %b\n'  "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC" "$status"
    printf '\n'
    cupcakes_os_dim_line "$app_description"
    printf '\n'
}

# ── Installed display ─────────────────────────────────────────────────────────

show_installed() {
    local app_id app_name app_group app_description
    local count=0 cols name_width desc_width

    cols="$(cupcakes_os_cols)"
    name_width=18
    desc_width=$((cols - name_width - 22))
    [[ $desc_width -lt 20 ]] && desc_width=20

    while IFS= read -r app_id; do
        [[ -n "$app_id" ]] || continue
        count=$((count + 1))
    done < <(read_selected_ids)

    if [[ "$count" -eq 0 ]]; then
        cupcakes_os_banner "Installed Apps" "No apps installed yet."
        cupcakes_os_dim_line "Run 'cupcakes-os-apps catalog' to browse what's available."
        printf '\n'
        return 0
    fi

    cupcakes_os_banner "Installed Apps" "${count} app(s) managed by Cupcakes OS."

    while IFS= read -r app_id; do
        [[ -n "$app_id" ]] || continue
        app_name="$(cupcakes_os_catalog_name "$app_id" 2>/dev/null || printf '%s' "$app_id")"
        app_group="$(cupcakes_os_catalog_group "$app_id" 2>/dev/null || printf 'Custom')"
        app_description="$(cupcakes_os_catalog_description "$app_id" 2>/dev/null || printf 'Managed by Cupcakes OS')"

        local id_col name_col desc_col
        id_col="$(cupcakes_os_trunc "$app_id" 14)"
        name_col="$(cupcakes_os_trunc "$app_name" "$name_width")"
        desc_col="$(cupcakes_os_trunc "$app_description" "$desc_width")"

        printf '  %b·%b  %-14s  %b%-*s%b  %b%s%b\n' \
            "$CUPCAKES_OS_GREEN" "$CUPCAKES_OS_NC" \
            "$id_col" \
            "$CUPCAKES_OS_DIM" "$name_width" "$name_col" "$CUPCAKES_OS_NC" \
            "$CUPCAKES_OS_FAINT" "$desc_col" "$CUPCAKES_OS_NC"
    done < <(read_selected_ids)

    printf '\n'
}

# ── Change helpers ────────────────────────────────────────────────────────────

print_changed_apps() {
    local action="$1"; shift
    local names=() name list=""
    for id in "$@"; do
        name="$(cupcakes_os_catalog_name "$id" 2>/dev/null || printf '%s' "$id")"
        names+=("$name")
    done
    for name in "${names[@]}"; do
        [[ -n "$list" ]] && list+=", "
        list+="$name"
    done
    cupcakes_os_success "${action}: ${list}"
}

show_dry_run() {
    local action="$1" no_rebuild="$2"; shift 2
    cupcakes_os_step "Dry run — no changes will be made"
    printf '\n'

    if [[ "$action" == "set" ]]; then
        if [[ $# -eq 0 ]]; then
            printf '  %bWould clear all installed apps%b\n' "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC"
        else
            printf '  %bWould replace app list with:%b\n' "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC"
            for id in "$@"; do
                local name
                name="$(cupcakes_os_catalog_name "$id" 2>/dev/null || printf '%s' "$id")"
                printf '    %b·%b  %s %b(%s)%b\n' \
                    "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC" \
                    "$name" \
                    "$CUPCAKES_OS_DIM" "$id" "$CUPCAKES_OS_NC"
            done
        fi
    else
        local color marker
        case "$action" in
            remove) color="$CUPCAKES_OS_RED";   marker="-" ;;
            *)      color="$CUPCAKES_OS_GREEN"; marker="+" ;;
        esac
        printf '  %bWould %s:%b\n' "$CUPCAKES_OS_WHITE" "$action" "$CUPCAKES_OS_NC"
        for id in "$@"; do
            local name
            name="$(cupcakes_os_catalog_name "$id" 2>/dev/null || printf '%s' "$id")"
            printf '    %b%s%b  %s %b(%s)%b\n' \
                "$color" "$marker" "$CUPCAKES_OS_NC" \
                "$name" \
                "$CUPCAKES_OS_DIM" "$id" "$CUPCAKES_OS_NC"
        done
    fi

    printf '\n'
    if [[ "$no_rebuild" == "false" ]]; then
        cupcakes_os_info "Would run: nixos-rebuild switch --flake ${config_dir}#${flake_target}"
    else
        cupcakes_os_info "Would write to apps.list only (skipping rebuild)"
    fi
    printf '\n'
}

main() {
    local command="${1:-}"
    shift || true

    local no_rebuild=false dry_run=false
    local -a args=()
    for arg in "$@"; do
        case "$arg" in
            --no-rebuild) no_rebuild=true ;;
            --dry-run)    dry_run=true; no_rebuild=true ;;
            *)            args+=("$arg") ;;
        esac
    done
    set -- "${args[@]+"${args[@]}"}"

    local app_id total
    local -a current=() new_list=() bundle_ids=() keeping=()

    case "$command" in
        catalog)
            show_catalog
            ;;
        search)
            if [[ -z "${1:-}" ]]; then
                cupcakes_os_error "Usage: cupcakes-os-apps search <term>"
                exit 1
            fi
            cupcakes_os_banner "App Search" "Results for '${1}'."
            search_apps "$1"
            ;;
        info)
            if [[ -z "${1:-}" ]]; then
                cupcakes_os_error "Usage: cupcakes-os-apps info <app-id>"
                exit 1
            fi
            show_info "$1"
            ;;
        installed)
            show_installed
            ;;
        rebuild)
            if [[ "$dry_run" == "true" ]]; then
                cupcakes_os_step "Dry run — no changes will be made"
                printf '\n'
                cupcakes_os_info "Would run: nixos-rebuild switch --flake ${config_dir}#${flake_target}"
                printf '\n'
                return 0
            fi
            ensure_layout
            cupcakes_os_banner "App Manager" "Applying current app selection."
            render_apps_module
            rebuild_system
            cupcakes_os_success "Done. System rebuilt."
            printf '\n'
            ;;
        set)
            validate_ids "$@"
            if [[ "$dry_run" == "true" ]]; then
                show_dry_run "set" "$no_rebuild" "$@"
                return 0
            fi
            ensure_layout
            cupcakes_os_banner "App Manager" "Replacing app selection."
            write_selected_ids "$@"
            render_apps_module
            if [[ "$no_rebuild" == "false" ]]; then
                rebuild_system
            fi
            total="$(read_selected_ids | wc -l | tr -d ' ')"
            cupcakes_os_success "Done. App selection replaced."
            cupcakes_os_info "Total installed: $total"
            printf '\n'
            ;;
        add)
            if [[ $# -eq 0 ]]; then
                cupcakes_os_error "Usage: cupcakes-os-apps add <app-id...>"
                exit 1
            fi
            validate_ids "$@"
            if [[ "$dry_run" == "true" ]]; then
                show_dry_run "add" "$no_rebuild" "$@"
                return 0
            fi
            ensure_layout
            cupcakes_os_banner "App Manager" "Adding apps to your system."
            while IFS= read -r app_id; do
                [[ -n "$app_id" ]] || continue
                current+=("$app_id")
            done < <(read_selected_ids)
            new_list=("${current[@]+"${current[@]}"}" "$@")
            write_selected_ids "${new_list[@]}"
            render_apps_module
            if [[ "$no_rebuild" == "false" ]]; then
                rebuild_system
            fi
            total="$(read_selected_ids | wc -l | tr -d ' ')"
            print_changed_apps "Added" "$@"
            cupcakes_os_info "Total installed: $total"
            printf '\n'
            ;;
        remove)
            if [[ $# -eq 0 ]]; then
                cupcakes_os_error "Usage: cupcakes-os-apps remove <app-id...>"
                exit 1
            fi
            validate_ids "$@"
            if [[ "$dry_run" == "true" ]]; then
                show_dry_run "remove" "$no_rebuild" "$@"
                return 0
            fi
            ensure_layout
            cupcakes_os_banner "App Manager" "Removing apps from your system."
            local removing_set=" $* "
            while IFS= read -r app_id; do
                [[ -n "$app_id" ]] || continue
                case "$removing_set" in
                    *" $app_id "*) ;;
                    *) keeping+=("$app_id") ;;
                esac
            done < <(read_selected_ids)
            write_selected_ids "${keeping[@]+"${keeping[@]}"}"
            render_apps_module
            if [[ "$no_rebuild" == "false" ]]; then
                rebuild_system
            fi
            total="$(read_selected_ids | wc -l | tr -d ' ')"
            print_changed_apps "Removed" "$@"
            cupcakes_os_info "Total installed: $total"
            printf '\n'
            ;;
        bundle)
            if [[ -z "${1:-}" ]]; then
                usage
                exit 1
            fi
            validate_bundle "$1"
            while IFS= read -r app_id; do
                [[ -n "$app_id" ]] || continue
                bundle_ids+=("$app_id")
            done < <(cupcakes_os_catalog_bundle_ids "$1")
            if [[ "$dry_run" == "true" ]]; then
                show_dry_run "add" "$no_rebuild" "${bundle_ids[@]}"
                return 0
            fi
            ensure_layout
            cupcakes_os_banner "App Manager" "Installing the '${1}' bundle."
            while IFS= read -r app_id; do
                [[ -n "$app_id" ]] || continue
                current+=("$app_id")
            done < <(read_selected_ids)
            new_list=("${current[@]+"${current[@]}"}" "${bundle_ids[@]}")
            write_selected_ids "${new_list[@]}"
            render_apps_module
            if [[ "$no_rebuild" == "false" ]]; then
                rebuild_system
            fi
            total="$(read_selected_ids | wc -l | tr -d ' ')"
            cupcakes_os_success "Done. The '${1}' bundle has been applied."
            cupcakes_os_info "Total installed: $total"
            printf '\n'
            ;;
        "" | help | --help | -h)
            usage
            ;;
        *)
            cupcakes_os_error "Unknown command: $command"
            printf '\n'
            usage
            exit 1
            ;;
    esac
}

main "$@"
