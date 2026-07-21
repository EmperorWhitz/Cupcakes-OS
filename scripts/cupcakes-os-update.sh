#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
script_self="${BASH_SOURCE[0]}"
script_hash_before="$(sha256sum "$script_self" 2>/dev/null | awk '{print $1}' || true)"
ui_lib="${CUPCAKES_OS_UI_LIB:-$script_dir/cupcakes-os-ui.sh}"

if [[ ! -f "$ui_lib" && -f /etc/cupcakes-os/ui.sh ]]; then
    ui_lib="/etc/cupcakes-os/ui.sh"
fi

# shellcheck source=/dev/null
source "$ui_lib"

config_dir="${CUPCAKES_OS_SYSTEM_CONFIG:-/etc/nixos}"
command_name="${CUPCAKES_OS_UPDATE_COMMAND:-$(basename "$0")}"
repo_git_url="${CUPCAKES_OS_REPO_GIT_URL:-https://github.com/AnimatedGTVR/cupcakes-os.git}"
repo_ref="${CUPCAKES_OS_REPO_REF:-main}"
upstream_dir="${CUPCAKES_OS_UPSTREAM_DIR:-$config_dir/.cupcakes-os-upstream}"
flake_config_name="${CUPCAKES_OS_FLAKE_CONFIG_NAME:-cupcakes-os}"
fallback_ref="${CUPCAKES_OS_FALLBACK_REF:-}"
fallback_mode="${CUPCAKES_OS_FALLBACK_MODE:-0}"
allow_downgrade="${CUPCAKES_OS_ALLOW_DOWNGRADE:-0}"
effective_ref=""
effective_ref_reason=""
update_tmp_files=()
update_tmp_dirs=()

cleanup_update_tmp_files() {
    local file
    for file in "${update_tmp_files[@]:-}"; do
        [[ -n "$file" ]] && rm -f "$file" 2>/dev/null || true
    done

    local dir
    for dir in "${update_tmp_dirs[@]:-}"; do
        [[ -n "$dir" ]] && rm -rf "$dir" 2>/dev/null || true
    done
}

drop_upstream_git_metadata() {
    [[ -n "${upstream_dir:-}" && -d "$upstream_dir/.git" ]] || return 0
    rm -rf "$upstream_dir/.git"
}

on_update_exit() {
    local rc="$1"
    cleanup_update_tmp_files
    if [[ "$rc" -ne 0 ]]; then
        cupcakes_os_error "Update failed before completion; existing flake.nix was left untouched unless an atomic replacement had already passed validation." >&2 || true
    fi
}

trap 'on_update_exit "$?"' EXIT

# ── Channel helpers ───────────────────────────────────────────────────────────

channel_file() {
    printf '%s/cupcakes-os/channel' "$config_dir"
}

read_channel() {
    local cf
    if [[ -n "${CUPCAKES_OS_RELEASE_CHANNEL:-}" ]]; then
        printf '%s' "$CUPCAKES_OS_RELEASE_CHANNEL"
        return
    fi
    cf="$(channel_file)"
    if [[ -f "$cf" ]]; then
        tr -d '[:space:]' < "$cf"
    else
        printf 'stable'
    fi
}

write_channel() {
    local name="${1:-stable}" cf
    cf="$(channel_file)"
    mkdir -p "$(dirname "$cf")"
    printf '%s\n' "$name" > "$cf"
}

installed_version() {
    local candidate
    for candidate in \
        "${CUPCAKES_OS_INSTALLED_VERSION:-}" \
        "$config_dir/cupcakes-os/VERSION" \
        /etc/cupcakes-os/VERSION \
        "$script_dir/../VERSION"; do
        if [[ -n "$candidate" && -f "$candidate" ]]; then
            tr -d '[:space:]' < "$candidate"
            return
        elif [[ -n "$candidate" && ! -e "$candidate" ]]; then
            printf '%s' "$candidate"
            return
        fi
    done
    printf '0'
}

tag_base_version() {
    local tag="${1#v}"
    sed -E 's/^([0-9]+([.][0-9]+)*).*/\1/' <<<"$tag"
}

is_final_release_tag() {
    [[ "$1" =~ ^v[0-9]+([.][0-9]+)*$ ]]
}

is_demo_release_tag() {
    [[ "$1" =~ ^v[0-9]+([.][0-9]+)*.*(DEMO|[Dd]emo|[Dd]ev|[Pp]re|[Rr][Cc]).*$ ]]
}

version_lt() {
    local a="$1" b="$2" first
    [[ "$a" == "$b" ]] && return 1
    first="$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n1)"
    [[ "$first" == "$a" ]]
}

list_release_tags() {
    if [[ -n "${CUPCAKES_OS_RELEASE_TAGS:-}" ]]; then
        printf '%s\n' $CUPCAKES_OS_RELEASE_TAGS
        return
    fi
    git ls-remote --tags "$repo_git_url" 'refs/tags/v*' 2>/dev/null \
        | grep -v '\^{}' \
        | awk '{print $2}' \
        | sed 's|refs/tags/||'
}

latest_tag_from_list() {
    sort -V | tail -n1
}

resolve_update_ref() {
    local channel="$1" current_version="$2" tags final_tag demo_tag older_tag

    effective_ref=""
    effective_ref_reason=""

    if [[ "$fallback_mode" -eq 1 ]]; then
        effective_ref="$fallback_ref"
        effective_ref_reason="explicit fallback requested"
        allow_downgrade=1
        return 0
    fi

    case "$channel" in
        unstable)
            effective_ref="main"
            effective_ref_reason="unstable channel tracks main"
            return 0
            ;;
        demo|dev)
            tags="$(list_release_tags | grep -E '^v[0-9]+([.][0-9]+)*.*(DEMO|[Dd]emo|[Dd]ev|[Pp]re|[Rr][Cc]).*$' || true)"
            demo_tag="$(printf '%s\n' "$tags" | awk -v cur="$current_version" 'NF && $0 ~ ("^v" cur) { print }' | latest_tag_from_list)"
            if [[ -z "$demo_tag" ]]; then
                demo_tag="$(printf '%s\n' "$tags" | latest_tag_from_list)"
            fi
            if [[ -n "$demo_tag" ]]; then
                effective_ref="$demo_tag"
                effective_ref_reason="demo channel selected latest demo/dev tag"
                return 0
            fi
            ;;
        stable|"")
            tags="$(list_release_tags || true)"
            final_tag="$(
                printf '%s\n' "$tags" \
                    | grep -E '^v[0-9]+([.][0-9]+)*$' \
                    | while IFS= read -r tag; do
                        [[ -n "$tag" ]] || continue
                        if ! version_lt "$(tag_base_version "$tag")" "$current_version"; then
                            printf '%s\n' "$tag"
                        fi
                    done \
                    | latest_tag_from_list
            )"
            if [[ -n "$final_tag" ]]; then
                effective_ref="$final_tag"
                effective_ref_reason="stable channel selected latest final tag not older than installed version"
                return 0
            fi

            demo_tag="$(
                printf '%s\n' "$tags" \
                    | grep -E '^v[0-9]+([.][0-9]+)*.*(DEMO|[Dd]emo|[Dd]ev|[Pp]re|[Rr][Cc]).*$' \
                    | awk -v cur="$current_version" 'NF && $0 ~ ("^v" cur) { print }' \
                    | latest_tag_from_list
            )"
            if [[ -n "$demo_tag" ]]; then
                effective_ref="$demo_tag"
                effective_ref_reason="stable channel found no final tag for this release line; using matching demo/dev tag"
                return 0
            fi

            older_tag="$(printf '%s\n' "$tags" | grep -E '^v[0-9]+([.][0-9]+)*$' | latest_tag_from_list)"
            if [[ -n "$older_tag" ]]; then
                effective_ref="$older_tag"
                effective_ref_reason="only older final tag was available; downgrade guard will refuse this without fallback"
                return 0
            fi
            ;;
        *)
            cupcakes_os_warn "Unknown channel '${channel}' — using unstable/main." >&2
            effective_ref="main"
            effective_ref_reason="unknown channel fallback to main"
            return 0
            ;;
    esac

    cupcakes_os_error "Could not resolve a Cupcakes OS update ref for channel '${channel}'."
    return 1
}

guard_against_accidental_downgrade() {
    local current_version="$1" selected_ref="$2" selected_version

    [[ "$selected_ref" == "main" || "$allow_downgrade" -eq 1 ]] && return 0
    selected_version="$(tag_base_version "$selected_ref")"
    if version_lt "$selected_version" "$current_version"; then
        cupcakes_os_error "Refusing accidental downgrade."
        cupcakes_os_error "  installed version : ${current_version}"
        cupcakes_os_error "  selected ref      : ${selected_ref}"
        cupcakes_os_error "  selected version  : ${selected_version}"
        cupcakes_os_error "Use an explicit fallback command to downgrade intentionally:"
        cupcakes_os_error "  sudo cupcakes-os fallback --release ${selected_ref}"
        return 1
    fi
}

# ── Usage ─────────────────────────────────────────────────────────────────────

usage() {
    cupcakes_os_banner "System Update" "Keep your Cupcakes OS installation up to date."
    printf '  %bCommands%b\n\n' "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC"
    printf '  %bnixos update%b  /  %bupdate%b  /  %bcupcakes-os-update%b\n' \
        "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Sync the latest Cupcakes OS files and rebuild the system."
    printf '\n'
    printf '  %bnixos rollback%b  /  %brollback%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Roll back to the previous system generation."
    printf '\n'
    printf '  %bnixos channel%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Show the current update channel."
    printf '\n'
    printf '  %bnixos channel list%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  List all available channels."
    printf '\n'
    printf '  %bnixos channel set <stable|demo|unstable>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Switch to a different update channel."
    printf '\n'
    printf '  %bcupcakes-os fallback --release <tag>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Intentionally downgrade or pin to an older release."
    printf '\n'
}

parse_fallback_args() {
    case "${1:-}" in
        --release)
            fallback_ref="${2:-}"
            ;;
        --force)
            fallback_ref="${2:-}"
            ;;
        help|--help|-h|"")
            printf 'Usage: cupcakes-os fallback --release <tag>\n'
            exit 0
            ;;
        *)
            cupcakes_os_error "Usage: cupcakes-os fallback --release <tag>"
            exit 1
            ;;
    esac

    if [[ -z "$fallback_ref" ]]; then
        cupcakes_os_error "Fallback release tag is required."
        exit 1
    fi
    [[ "$fallback_ref" == v* || "$fallback_ref" == "main" ]] || fallback_ref="v${fallback_ref}"
    fallback_mode=1
    allow_downgrade=1
}

# ── Channel subcommand ────────────────────────────────────────────────────────

handle_channel_command() {
    local sub="${1:-}" channel

    case "$sub" in
        "" | show)
            channel="$(read_channel)"
            cupcakes_os_banner "Update Channel" "Your system receives updates from this channel."
            printf '  %bChannel%b    %b%s%b\n' "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_CYAN" "$channel" "$CUPCAKES_OS_NC"
            case "$channel" in
                stable)
                    cupcakes_os_dim_line "  Tracks tagged Cupcakes OS releases. Recommended for most users."
                    ;;
                unstable)
                    cupcakes_os_dim_line "  Tracks the main development branch. May include breaking changes."
                    ;;
                demo|dev)
                    cupcakes_os_dim_line "  Tracks tagged demo/dev builds for the installed release line."
                    ;;
            esac
            printf '\n'
            ;;
        list)
            cupcakes_os_banner "Update Channels" "Choose how your system receives updates."
            channel="$(read_channel)"

            cupcakes_os_card_start "Available Channels"

            local marker_stable="" marker_demo="" marker_unstable=""
            [[ "$channel" == "stable" ]]   && marker_stable=" %b◀ current%b"
            [[ "$channel" == "demo" || "$channel" == "dev" ]] && marker_demo=" %b◀ current%b"
            [[ "$channel" == "unstable" ]] && marker_unstable=" %b◀ current%b"

            printf '  %b│%b  %bstable%b' "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
            # shellcheck disable=SC2059
            [[ -n "$marker_stable" ]]   && printf "  $marker_stable" "$CUPCAKES_OS_GREEN" "$CUPCAKES_OS_NC"
            printf '\n'
            printf '  %b│%b  %bLatest tagged Cupcakes OS releases. Recommended for most users.%b\n' \
                "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC"
            printf '\n'

            printf '  %b│%b  %bdemo%b' "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
            # shellcheck disable=SC2059
            [[ -n "$marker_demo" ]] && printf "  $marker_demo" "$CUPCAKES_OS_GREEN" "$CUPCAKES_OS_NC"
            printf '\n'
            printf '  %b│%b  %bTagged demo/dev builds for the installed release line.%b\n' \
                "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC"
            printf '\n'

            printf '  %b│%b  %bunstable%b' "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
            # shellcheck disable=SC2059
            [[ -n "$marker_unstable" ]] && printf "  $marker_unstable" "$CUPCAKES_OS_GREEN" "$CUPCAKES_OS_NC"
            printf '\n'
            printf '  %b│%b  %bDevelopment builds from the main branch. May include breaking changes.%b\n' \
                "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC"
            printf '  %b│%b\n' "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC"

            cupcakes_os_card_end

            printf '\n'
            ;;
        set)
            local new_channel="${2:-}"
            case "$new_channel" in
                stable | demo | dev | unstable)
                    run_as_root env \
                        CUPCAKES_OS_SYSTEM_CONFIG="$config_dir" \
                        bash -c '
                            channel_file="'"$config_dir"'/cupcakes-os/channel"
                            mkdir -p "$(dirname "$channel_file")"
                            printf "%s\n" "'"$new_channel"'" > "$channel_file"
                        '
                    cupcakes_os_success "Channel set to '${new_channel}'."
                    cupcakes_os_dim_line "Run 'update' to apply the new channel."
                    printf '\n'
                    ;;
                "")
                    cupcakes_os_error "Specify a channel: stable, demo, or unstable"
                    exit 1
                    ;;
                *)
                    cupcakes_os_error "Unknown channel: ${new_channel}. Use 'stable', 'demo', or 'unstable'."
                    exit 1
                    ;;
            esac
            ;;
        *)
            cupcakes_os_error "Unknown channel subcommand: ${sub}"
            exit 1
            ;;
    esac
}

# ── System helpers ────────────────────────────────────────────────────────────

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
        return
    fi

    if command -v sudo >/dev/null 2>&1; then
        sudo "$@"
        return
    fi

    cupcakes_os_error "This command needs root privileges. Run it as root or install sudo."
    exit 1
}

confirm() {
    local prompt="$1"
    local answer=""
    if [[ ! -t 0 ]]; then
        return 0
    fi
    printf '  %b%s [Y/n]%b ' "$CUPCAKES_OS_YELLOW" "$prompt" "$CUPCAKES_OS_NC"
    read -r answer
    case "$answer" in
        ""|y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

copy_upstream_file() {
    local source="$1"
    local destination="$2"

    if [[ ! -f "$source" ]]; then
        cupcakes_os_error "Required upstream file is missing."
        cupcakes_os_error "  selected ref: ${effective_ref:-${repo_ref:-unknown}}"
        cupcakes_os_error "  upstream dir : ${upstream_dir}"
        cupcakes_os_error "  missing file : ${source#"$upstream_dir"/}"
        cupcakes_os_error "Retry with: sudo cupcakes-os update"
        return 1
    fi

    mkdir -p "$(dirname "$destination")"
    cp "$source" "$destination"
}

copy_first_existing_upstream_file() {
    local destination="$1"
    shift

    local source=""
    for source in "$@"; do
        if [[ -f "$source" ]]; then
            mkdir -p "$(dirname "$destination")"
            cp "$source" "$destination"
            return 0
        fi
    done

    cupcakes_os_error "None of the expected upstream files were found for ${destination##*/}."
    cupcakes_os_error "  selected ref: ${effective_ref:-${repo_ref:-unknown}}"
    cupcakes_os_error "  upstream dir : ${upstream_dir}"
    cupcakes_os_error "Retry with: sudo cupcakes-os update"
    return 1
}

maybe_reexec_synced_updater() {
    local synced_script="$config_dir/cupcakes-os/update.sh"
    local script_hash_after=""

    [[ "${CUPCAKES_OS_UPDATE_REEXECED:-0}" != 1 ]] || return 0
    [[ -n "$script_hash_before" && -f "$synced_script" ]] || return 0

    script_hash_after="$(sha256sum "$synced_script" 2>/dev/null | awk '{print $1}' || true)"
    [[ -n "$script_hash_after" && "$script_hash_after" != "$script_hash_before" ]] || return 0

    cupcakes_os_info "Restarting with the synced updater."
    exec env \
        CUPCAKES_OS_UPDATE_REEXECED=1 \
        CUPCAKES_OS_UPDATE_COMMAND="$command_name" \
        CUPCAKES_OS_SYSTEM_CONFIG="$config_dir" \
        CUPCAKES_OS_REPO_GIT_URL="$repo_git_url" \
        CUPCAKES_OS_REPO_REF="$repo_ref" \
        CUPCAKES_OS_UPSTREAM_DIR="$upstream_dir" \
        CUPCAKES_OS_FLAKE_CONFIG_NAME="$flake_config_name" \
        CUPCAKES_OS_UI_LIB="$ui_lib" \
        bash "$synced_script"
}

# ── Upstream checkout validation ──────────────────────────────────────────────

release_uses_modern_layout() {
    local selected_ref="$1"
    [[ "$selected_ref" == "main" ]] && return 0
    is_demo_release_tag "$selected_ref" && return 1
    is_final_release_tag "$selected_ref" || return 1
    ! version_lt "$(tag_base_version "$selected_ref")" "3.14"
}

required_upstream_paths() {
    local selected_ref="${1:-main}"
    cat <<'EOF'
VERSION
nix/modules/cupcakes-os-options.nix
nix/modules/installed-base.nix
nix/modules/anix.nix
scripts/cupcakes-os-update.sh
scripts/cupcakes-os-installer.sh
scripts/cupcakes-os-ui.sh
scripts/cupcakes-os-config.sh
scripts/cupcakes-os.sh
scripts/cupcakes-os-desktop.sh
scripts/cupcakes-os-doctor.sh
scripts/cupcakes-os-recovery.sh
scripts/cupcakes-os-welcome.sh
scripts/anix.sh
scripts/cupcakes-os-app-catalog.sh
scripts/cupcakes-os-apps.sh
scripts/cupcakes-os-support-report.sh
scripts/cupcakes-os-hardware-test.sh
scripts/cupcakes-os-desktop-profiles.sh
scripts/cupcakes-os-session-setup.sh
scripts/cupcakes-os-theme-sync.sh
assets/cupcakes-os-title.txt
assets/fastfetch-logo.txt
assets/fastfetch-config.jsonc
assets/bootloader/background.png
assets/bootloader/theme.txt
assets/plymouth/cupcakes-os.plymouth
assets/plymouth/cupcakes-os.script
assets/Effects/LaunchingCupcakes-OS.mp3
assets/wallpapers/collection
assets/wallpapers/collection/oceandusk.png
assets/wallpaper-themes
EOF

    if release_uses_modern_layout "$selected_ref"; then
        cat <<'EOF'
nix/modules/desktops
nix/pkgs/mango.nix
nix/pkgs/modularity.nix
scripts/cupcakes-os-repair-flake-purity.sh
assets/mango/config.conf
EOF
    fi
}

validate_upstream_checkout() {
    local checkout_dir="$1"
    local selected_ref="$2"
    local rel missing=0

    while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        if [[ ! -e "$checkout_dir/$rel" ]]; then
            if [[ "$missing" -eq 0 ]]; then
                cupcakes_os_error "Fetched Cupcakes OS checkout is incomplete; refusing to update installed files."
                cupcakes_os_error "  selected ref: ${selected_ref}"
                cupcakes_os_error "  checkout    : ${checkout_dir}"
                cupcakes_os_error "  missing:"
            fi
            printf '    - %s\n' "$rel" >&2
            missing=1
        fi
    done < <(required_upstream_paths "$selected_ref")

    if [[ "$missing" -ne 0 ]]; then
        cupcakes_os_error "Retry with: sudo cupcakes-os update"
        return 1
    fi
}

prepare_verified_upstream() {
    local selected_ref="$1"
    local parent tmp_checkout timestamp

    parent="$(dirname "$upstream_dir")"
    timestamp="$(date +%Y%m%d-%H%M%S)"
    tmp_checkout="${upstream_dir}.tmp-$$-${timestamp}"
    update_tmp_dirs+=("$tmp_checkout")

    mkdir -p "$parent"
    rm -rf "$tmp_checkout"

    cupcakes_os_info "Fetching Cupcakes OS files (${selected_ref}) into a temporary checkout."
    if ! git clone --depth=1 --branch "$selected_ref" "$repo_git_url" "$tmp_checkout"; then
        cupcakes_os_error "Failed to clone ${repo_git_url} at ${selected_ref}."
        cupcakes_os_error "Check your internet connection, then run: sudo ${command_name:-nixos} update"
        return 1
    fi

    validate_upstream_checkout "$tmp_checkout" "$selected_ref" || return 1

    rm -rf "$tmp_checkout/.git"
    rm -rf "$upstream_dir"
    mv "$tmp_checkout" "$upstream_dir"

    local i
    for i in "${!update_tmp_dirs[@]}"; do
        if [[ "${update_tmp_dirs[$i]}" == "$tmp_checkout" ]]; then
            unset 'update_tmp_dirs[i]'
            break
        fi
    done
}

# ── File sync ─────────────────────────────────────────────────────────────────

install_mango_config_asset() {
    local cupcakes_os_dir="$config_dir/cupcakes-os"
    local dest="$cupcakes_os_dir/mango/config.conf"
    local candidate

    mkdir -p "$(dirname "$dest")"
    for candidate in \
        "$upstream_dir/assets/mango/config.conf" \
        "$config_dir/.cupcakes-os-upstream/assets/mango/config.conf" \
        /etc/cupcakes-os/mango/config.conf \
        "$config_dir/assets/mango/config.conf"; do
        if [[ -f "$candidate" ]]; then
            cp "$candidate" "$dest"
            return 0
        fi
    done

    : > "$dest"
}

rewrite_installed_mango_config_paths() {
    local cupcakes_os_dir="$config_dir/cupcakes-os"
    local bad_store='/nix/store'
    bad_store="${bad_store}/assets/mango/config.conf"
    local file

    for file in "$cupcakes_os_dir/cupcakes-os-options.nix" "$cupcakes_os_dir/installed-base.nix"; do
        [[ -f "$file" ]] || continue
        sed -i \
            -e "s|\"${bad_store}\"|./mango/config.conf|g" \
            -e "s|${bad_store}|./mango/config.conf|g" \
            -e 's|../../assets/mango/config\.conf|./mango/config.conf|g' \
            -e 's|../../../assets/mango/config\.conf|./mango/config.conf|g' \
            "$file"
    done

    if [[ -d "$cupcakes_os_dir/desktops" ]]; then
        while IFS= read -r -d '' file; do
            sed -i \
                -e "s|\"${bad_store}\"|../mango/config.conf|g" \
                -e "s|${bad_store}|../mango/config.conf|g" \
                -e 's|../../assets/mango/config\.conf|../mango/config.conf|g' \
                -e 's|../../../assets/mango/config\.conf|../mango/config.conf|g' \
                "$file"
        done < <(
            grep -RIlZ \
                -e "$bad_store" \
                -e '../../assets/mango/config.conf' \
                -e '../../../assets/mango/config.conf' \
                "$cupcakes_os_dir/desktops" 2>/dev/null || true
        )
    fi
}

sync_cupcakes_os_files() {
    local effective_ref="$1"
    local cupcakes_os_dir="$config_dir/cupcakes-os"
    local upstream_background="$upstream_dir/assets/bootloader/background.png"
    local upstream_limine_background="$upstream_dir/assets/bootloader/limine-background.png"
    local upstream_theme="$upstream_dir/assets/bootloader/theme.txt"
    local limine_source=""

    if ! command -v git >/dev/null 2>&1; then
        cupcakes_os_error "The git command is required to fetch the latest Cupcakes OS files."
        return 1
    fi

    prepare_verified_upstream "$effective_ref" || return 1

    mkdir -p "$cupcakes_os_dir/plymouth" "$cupcakes_os_dir/bootloader" "$cupcakes_os_dir/effects" "$cupcakes_os_dir/mango"
    copy_upstream_file "$upstream_dir/VERSION" "$cupcakes_os_dir/VERSION"
    copy_upstream_file "$upstream_dir/nix/modules/cupcakes-os-options.nix" "$cupcakes_os_dir/cupcakes-os-options.nix"
    if [[ -d "$upstream_dir/nix/modules/desktops" ]]; then
        rm -rf "$cupcakes_os_dir/desktops"
        cp -R "$upstream_dir/nix/modules/desktops" "$cupcakes_os_dir/desktops"
    fi
    copy_upstream_file "$upstream_dir/nix/modules/anix.nix" "$cupcakes_os_dir/anix-module.nix"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-ui.sh" "$cupcakes_os_dir/ui.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-config.sh" "$cupcakes_os_dir/config.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os.sh" "$cupcakes_os_dir/cupcakes-os.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-desktop.sh" "$cupcakes_os_dir/desktop.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-doctor.sh" "$cupcakes_os_dir/doctor.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-recovery.sh" "$cupcakes_os_dir/recovery.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-welcome.sh" "$cupcakes_os_dir/welcome.sh"
    copy_upstream_file "$upstream_dir/scripts/anix.sh" "$cupcakes_os_dir/anix.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-app-catalog.sh" "$cupcakes_os_dir/app-catalog.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-apps.sh" "$cupcakes_os_dir/apps.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-support-report.sh" "$cupcakes_os_dir/support-report.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-hardware-test.sh" "$cupcakes_os_dir/hardware-test.sh"
    if [[ -f "$upstream_dir/scripts/cupcakes-os-repair-flake-purity.sh" ]]; then
        copy_upstream_file "$upstream_dir/scripts/cupcakes-os-repair-flake-purity.sh" "$cupcakes_os_dir/repair-flake-purity.sh"
    fi
    copy_first_existing_upstream_file \
        "$cupcakes_os_dir/default-wallpaper.png" \
        "$upstream_dir/assets/wallpapers/collection/Daytime-MNT.jpg" \
        "$upstream_dir/assets/wallpapers/collection/bluehorizon.png" \
        "$upstream_dir/assets/wallpapers/collection/astronautwallpaper.png"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-desktop-profiles.sh" "$cupcakes_os_dir/desktop-profiles.sh"
    copy_upstream_file "$upstream_dir/nix/modules/installed-base.nix" "$cupcakes_os_dir/installed-base.nix"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-session-setup.sh" "$cupcakes_os_dir/session-setup.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-theme-sync.sh" "$cupcakes_os_dir/theme-sync.sh"
    copy_upstream_file "$upstream_dir/scripts/cupcakes-os-update.sh" "$cupcakes_os_dir/update.sh"
    copy_upstream_file "$upstream_dir/assets/cupcakes-os-title.txt" "$cupcakes_os_dir/title.txt"
    copy_upstream_file "$upstream_dir/assets/fastfetch-logo.txt" "$cupcakes_os_dir/fastfetch-logo.txt"
    copy_upstream_file "$upstream_dir/assets/fastfetch-config.jsonc" "$cupcakes_os_dir/fastfetch-config.jsonc"
    copy_first_existing_upstream_file \
        "$cupcakes_os_dir/effects/v3StartingCupcakes-OS.mp3" \
        "$upstream_dir/assets/Effects/v3StartingCupcakes-OS.mp3" \
        "$upstream_dir/assets/Effects/LaunchingCupcakes-OS.mp3"
    copy_upstream_file "$upstream_dir/assets/plymouth/cupcakes-os.plymouth" "$cupcakes_os_dir/plymouth/cupcakes-os.plymouth"
    copy_upstream_file "$upstream_dir/assets/plymouth/cupcakes-os.script" "$cupcakes_os_dir/plymouth/cupcakes-os.script"
    install_mango_config_asset
    if [[ -f "$cupcakes_os_dir/mango/config.conf" ]]; then
        rewrite_installed_mango_config_paths
    fi

    if [[ ! -f "$upstream_background" || ! -f "$upstream_theme" ]]; then
        cupcakes_os_error "The latest Cupcakes OS bootloader assets are incomplete."
        return 1
    fi

    limine_source="$upstream_background"
    if [[ -f "$upstream_limine_background" ]]; then
        limine_source="$upstream_limine_background"
    fi

    install -Dm0644 "$upstream_background" "$cupcakes_os_dir/bootloader/background.png"
    install -Dm0644 "$limine_source" "$cupcakes_os_dir/bootloader/limine-background.png"
    install -Dm0644 "$upstream_theme" "$cupcakes_os_dir/bootloader/theme.txt"
    mkdir -p "$cupcakes_os_dir/wallpapers" "$cupcakes_os_dir/themes" "$cupcakes_os_dir/pkgs"
    cp "$upstream_dir/assets/wallpapers/collection/"* "$cupcakes_os_dir/wallpapers/"
    cp "$upstream_dir/assets/wallpaper-themes/"* "$cupcakes_os_dir/themes/"
    if [[ -f "$upstream_dir/nix/pkgs/mango.nix" ]]; then
        copy_upstream_file "$upstream_dir/nix/pkgs/mango.nix" "$cupcakes_os_dir/pkgs/mango.nix"
    fi
    if [[ -f "$upstream_dir/nix/pkgs/modularity.nix" ]]; then
        copy_upstream_file "$upstream_dir/nix/pkgs/modularity.nix" "$cupcakes_os_dir/pkgs/modularity.nix"
    fi

    if [[ ! -f "$cupcakes_os_dir/apps.list" ]]; then
        : > "$cupcakes_os_dir/apps.list"
    fi

    if [[ ! -f "$cupcakes_os_dir/apps.nix" ]]; then
        cat > "$cupcakes_os_dir/apps.nix" <<'EOF'
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
  ];
}
EOF
    fi

    drop_upstream_git_metadata
}

# ── Flake layout check ────────────────────────────────────────────────────────

validate_flake_syntax() {
    local file="$1"
    local output=""

    if command -v nix-instantiate >/dev/null 2>&1; then
        if output="$(nix-instantiate --parse "$file" 2>&1)"; then
            return 0
        fi
        if grep -q '/nix/var/nix/db/big-lock.*Permission denied' <<<"$output"; then
            grep -q 'nixosConfigurations' "$file" && grep -q 'nixosSystem' "$file"
            return
        fi
        printf '%s\n' "$output" >&2
        return 1
    elif command -v nix >/dev/null 2>&1; then
        if output="$(nix --extra-experimental-features "nix-command" eval \
            --expr "builtins.seq (import ${file}) true" 2>&1)"; then
            return 0
        fi
        if grep -q '/nix/var/nix/db/big-lock.*Permission denied' <<<"$output"; then
            grep -q 'nixosConfigurations' "$file" && grep -q 'nixosSystem' "$file"
            return
        fi
        printf '%s\n' "$output" >&2
        return 1
    else
        grep -q 'nixosConfigurations' "$file" && grep -q 'nixosSystem' "$file"
    fi
}

write_installed_flake() {
    local flake_file="$config_dir/flake.nix"
    local flake_tmp backup timestamp
    local removed=0

    mkdir -p "$config_dir"
    flake_tmp="$(mktemp "${flake_file}.tmp.XXXXXX")"
    update_tmp_files+=("$flake_tmp")

    cat > "$flake_tmp" <<EOF
{
  description = "Cupcakes OS installed system";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }: {
    nixosConfigurations = {
      "${flake_config_name}" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
        ];
      };
    };
  };
}
EOF

    if ! validate_flake_syntax "$flake_tmp"; then
        cupcakes_os_error "Generated flake.nix failed syntax validation; keeping existing flake.nix unchanged."
        return 1
    fi

    if [[ -f "$flake_file" ]]; then
        timestamp="$(date +%Y%m%d-%H%M%S)"
        backup="${flake_file}.backup-${timestamp}"
        cp -f "$flake_file" "$backup"
        cupcakes_os_info "Backed up existing flake.nix to ${backup}"
    fi

    mv -f "$flake_tmp" "$flake_file"
    for i in "${!update_tmp_files[@]}"; do
        if [[ "${update_tmp_files[$i]}" == "$flake_tmp" ]]; then
            unset 'update_tmp_files[i]'
            removed=1
            break
        fi
    done
    [[ "$removed" -eq 1 ]] || true
}

repair_flake_layout_if_needed() {
    local flake_file="$config_dir/flake.nix"
    local cupcakes_os_dir="$config_dir/cupcakes-os"
    local needs_repair=0

    if [[ ! -f "$flake_file" ]]; then
        return 0
    fi

    if grep -Eq '(/nix/store|../../nix|../../../nix|nix/pkgs/mango\.nix|nix/pkgs/modularity\.nix)' "$flake_file"; then
        needs_repair=1
    elif [[ -d "$cupcakes_os_dir" ]] && grep -RIEq '(/nix/store|(\.\./){2,}assets/mango/config\.conf|(\.\./){2,}nix/|nix/(pkgs|modules)/(mango|modularity)\.nix)' "$cupcakes_os_dir"; then
        needs_repair=1
    elif ! nix --extra-experimental-features "nix-command flakes" \
        eval --no-write-lock-file "$config_dir#nixosConfigurations.${flake_config_name}.config.system.name" \
        >/dev/null 2>&1; then
        needs_repair=1
    fi

    if [[ "$needs_repair" -eq 1 ]]; then
        cupcakes_os_warn "Repairing the installed flake/module layout for pure evaluation."
        write_installed_flake
    fi
}

ensure_flake_layout() {
    local flake_file="$config_dir/flake.nix"
    local repair_script="$config_dir/cupcakes-os/repair-flake-purity.sh"

    if [[ ! -f "$flake_file" ]]; then
        cupcakes_os_warn "No flake.nix found in $config_dir — creating a flake-native Cupcakes OS layout."
        write_installed_flake
    fi

    if [[ ! -f "$config_dir/cupcakes-os-local.nix" ]]; then
        cupcakes_os_error "Missing $config_dir/cupcakes-os-local.nix."
        cupcakes_os_error "Reinstall from the current Cupcakes OS ISO or restore the flake-native local module."
        return 1
    fi

    if [[ -f "$repair_script" ]]; then
        bash "$repair_script" || {
            cupcakes_os_error "Cupcakes OS could not repair known flake-purity issues."
            return 1
        }
    fi

    repair_flake_layout_if_needed
}

if [[ "${1:-}" == "__test-write-flake" ]]; then
    write_installed_flake
    validate_flake_syntax "$config_dir/flake.nix"
    exit 0
fi

if [[ "${1:-}" == "__test-validate-upstream" ]]; then
    validate_upstream_checkout "${2:?missing checkout dir}" "${3:-test-ref}"
    exit 0
fi

if [[ "${1:-}" == "__test-resolve-ref" ]]; then
    current_version="${2:-4.0}"
    channel="${3:-stable}"
    resolve_update_ref "$channel" "$current_version"
    guard_against_accidental_downgrade "$current_version" "$effective_ref"
    printf '%s\t%s\n' "$effective_ref" "$effective_ref_reason"
    exit 0
fi

if [[ "${1:-}" == "__test-resolve-fallback" ]]; then
    current_version="${2:-4.0}"
    fallback_ref="${3:-v2.5.0}"
    fallback_mode=1
    allow_downgrade=1
    resolve_update_ref "fallback" "$current_version"
    guard_against_accidental_downgrade "$current_version" "$effective_ref"
    printf '%s\t%s\n' "$effective_ref" "$effective_ref_reason"
    exit 0
fi

# ── Pre-flight checks ─────────────────────────────────────────────────────────

if ! command -v nix >/dev/null 2>&1; then
    cupcakes_os_error "The nix command is not available on this system."
    exit 1
fi

if ! command -v nixos-rebuild >/dev/null 2>&1; then
    cupcakes_os_error "The nixos-rebuild command is not available on this system."
    exit 1
fi

if [[ ! -d "$config_dir" ]]; then
    cupcakes_os_error "NixOS config directory not found: $config_dir"
    exit 1
fi

# ── Command routing ───────────────────────────────────────────────────────────

case "$command_name" in
    nixos)
        case "${1:-}" in
            update | upgrade)
                command_name="update"
                shift
                ;;
            rollback)
                command_name="rollback"
                shift
                ;;
            channel)
                shift
                handle_channel_command "$@"
                exit 0
                ;;
            "" | help | -h | --help)
                usage
                exit 0
                ;;
            *)
                cupcakes_os_error "Unknown nixos command: $1"
                usage >&2
                exit 1
                ;;
        esac
        ;;
esac

case "${1:-}" in
    fallback)
        command_name="fallback"
        shift
        parse_fallback_args "$@"
        set --
        ;;
esac

if [[ "$#" -gt 0 ]]; then
    cupcakes_os_error "This command does not take extra arguments yet."
    usage >&2
    exit 1
fi

# Re-exec as root, forwarding channel env vars too.
if [[ "$(id -u)" -ne 0 ]]; then
    run_as_root env \
        CUPCAKES_OS_UPDATE_COMMAND="$command_name" \
        CUPCAKES_OS_SYSTEM_CONFIG="$config_dir" \
        CUPCAKES_OS_REPO_GIT_URL="$repo_git_url" \
        CUPCAKES_OS_REPO_REF="$repo_ref" \
        CUPCAKES_OS_UPSTREAM_DIR="$upstream_dir" \
        CUPCAKES_OS_FLAKE_CONFIG_NAME="$flake_config_name" \
        CUPCAKES_OS_FALLBACK_REF="$fallback_ref" \
        CUPCAKES_OS_FALLBACK_MODE="$fallback_mode" \
        CUPCAKES_OS_ALLOW_DOWNGRADE="$allow_downgrade" \
        CUPCAKES_OS_UI_LIB="$ui_lib" \
        bash "$script_self" "$@"
    exit 0
fi

# ── Rollback ──────────────────────────────────────────────────────────────────

if [[ "$command_name" == "rollback" ]]; then
    cupcakes_os_banner "System Rollback" "Reverting to the previous system generation."
    cupcakes_os_step "Rolling back to the previous generation"
    printf '\n'
    nixos-rebuild switch --rollback
    printf '\n'
    cupcakes_os_success "Rollback complete."
    printf '\n'
    exit 0
fi

# ── Update ────────────────────────────────────────────────────────────────────

current_version="$(installed_version)"
channel="$(read_channel)"
if [[ "$fallback_mode" -eq 1 ]]; then
    channel="fallback"
fi

resolve_update_ref "$channel" "$current_version" || exit 1
guard_against_accidental_downgrade "$current_version" "$effective_ref" || exit 1

cupcakes_os_banner "System Update" "Channel: ${channel}  ·  Ref: ${effective_ref}"
printf '  %bCurrent installed version%b  %s\n' "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC" "$current_version"
printf '  %bSelected channel%b           %s\n' "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC" "$channel"
printf '  %bSelected update ref%b        %s\n' "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC" "$effective_ref"
printf '  %bReason%b                     %s\n\n' "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC" "$effective_ref_reason"

if [[ -x "$config_dir/cupcakes-os/anix.sh" ]]; then
    if confirm "Save a local ANIX snapshot before updating?"; then
        env ANIX_SYSTEM_CONFIG="$config_dir" ANIX_FLAKE_CONFIG_NAME="$flake_config_name" bash "$config_dir/cupcakes-os/anix.sh" save "anix: snapshot before Cupcakes OS update" || {
            cupcakes_os_warn "Snapshot failed or was cancelled; continuing with update."
            printf '\n'
        }
    fi
fi

sync_cupcakes_os_files "$effective_ref" || {
    cupcakes_os_error "Cupcakes OS could not fetch the latest project files."
    exit 1
}
cupcakes_os_success "Cupcakes OS files synced."
printf '\n'

maybe_reexec_synced_updater

ensure_flake_layout || {
    cupcakes_os_error "Cupcakes OS could not prepare a flake-native system update."
    exit 1
}

cupcakes_os_step "Updating flake inputs"
printf '\n'
nix --extra-experimental-features "nix-command flakes" flake update --flake "$config_dir"
printf '\n'

if git -C "$config_dir" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$config_dir" add \
        cupcakes-os/mango/config.conf \
        cupcakes-os/cupcakes-os-options.nix \
        cupcakes-os/installed-base.nix \
        cupcakes-os/desktops/mangowm.nix \
        cupcakes-os/ \
        2>/dev/null || true
fi

cupcakes_os_step "Rebuilding Cupcakes OS from $config_dir"
printf '\n'
nixos-rebuild switch --flake "$config_dir#${flake_config_name}"
printf '\n'

cupcakes_os_success "Cupcakes OS is up to date."
printf '\n'
