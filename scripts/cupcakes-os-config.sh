#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ui_lib="${CUPCAKES_OS_UI_LIB:-$script_dir/cupcakes-os-ui.sh}"

if [[ ! -f "$ui_lib" && -f /etc/cupcakes-os/ui.sh ]]; then
    ui_lib="/etc/cupcakes-os/ui.sh"
fi

# shellcheck source=/dev/null
source "$ui_lib"

config_dir="${CUPCAKES_OS_SYSTEM_CONFIG:-/etc/nixos}"
local_module="${config_dir}/cupcakes-os-local.nix"
wallpaper_dir="${CUPCAKES_OS_WALLPAPER_DIR:-/etc/cupcakes-os/wallpapers}"

# ── Helpers ───────────────────────────────────────────────────────────────────

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"; return
    fi
    if command -v sudo >/dev/null 2>&1; then
        sudo "$@"; return
    fi
    cupcakes_os_error "This command needs root privileges."
    exit 1
}

is_options_format() {
    [[ -f "$local_module" ]] && grep -q 'cupcakes-os\.user\.name' "$local_module" 2>/dev/null
}

require_options_format() {
    if ! is_options_format; then
        cupcakes_os_error "cupcakes-os-local.nix uses the legacy format."
        cupcakes_os_warn  "Reinstall or migrate to the v2.5 config format to use this command."
        printf '\n'
        exit 1
    fi
}

require_local_module() {
    if [[ ! -f "$local_module" ]]; then
        cupcakes_os_error "No cupcakes-os-local.nix found at ${local_module}."
        cupcakes_os_warn  "This command only works on an installed Cupcakes OS system."
        printf '\n'
        exit 1
    fi
}

# Read a single cupcakes-os.* value from cupcakes-os-local.nix.
# Usage: read_option "hostname"  or  read_option "keyboard.console"
read_option() {
    local key="$1"
    local escaped_key="${key//./\\.}"
    sed -nE "s|^[[:space:]]*cupcakes-os\\.${escaped_key}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*|\1|p" \
        "$local_module" | head -n1
}

# Replace a single cupcakes-os.* value in cupcakes-os-local.nix.
# Usage: write_option "hostname" "new-value"
write_option() {
    local key="$1" value="$2"
    local escaped_key="${key//./\\.}"
    sed -i -E \
        "s|^([[:space:]]*cupcakes-os\\.${escaped_key}[[:space:]]*=[[:space:]]*)\"[^\"]*\";|\1\"${value}\";|" \
        "$local_module"
}

# ── Display ───────────────────────────────────────────────────────────────────

show_config() {
    require_local_module

    local hostname timezone kb_console kb_xkb user_name desktop wallpaper disk state_ver
    hostname="$(read_option "hostname")"
    timezone="$(read_option "timezone")"
    kb_console="$(read_option "keyboard.console")"
    kb_xkb="$(read_option "keyboard.xkb")"
    user_name="$(read_option "user.name")"
    desktop="$(read_option "desktop")"
    wallpaper="$(read_option "wallpaper")"
    disk="$(read_option "disk")"
    state_ver="$(read_option "stateVersion")"

    if ! is_options_format; then
        cupcakes_os_banner "System Configuration" "Legacy format — upgrade to v2.5 to use cupcakes-os config set."
        cupcakes_os_warn "This system uses the pre-v2.5 configuration format."
        cupcakes_os_dim_line "Reinstall from the latest Cupcakes OS ISO to get the new format."
        printf '\n'
        return 0
    fi

    cupcakes_os_banner "System Configuration" "${local_module}"

    cupcakes_os_card_start "Current Settings"

    cupcakes_os_kv "hostname"      "${hostname:-—}"
    cupcakes_os_kv "timezone"      "${timezone:-—}"
    printf '  %b│%b  %b%-18s%b  %b%s%b  /  %b%s%b\n' \
        "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_DIM" "keyboard" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_CYAN" "${kb_console:-—}" "$CUPCAKES_OS_NC" \
        "$CUPCAKES_OS_DIM" "${kb_xkb:-—}" "$CUPCAKES_OS_NC"
    cupcakes_os_kv "desktop"       "${desktop:-—}"
    cupcakes_os_kv "wallpaper"     "${wallpaper:-—}"
    cupcakes_os_kv "user"          "${user_name:-—}"
    cupcakes_os_kv_faint "disk"    "${disk:-—}"
    cupcakes_os_kv_faint "state version" "${state_ver:-—}"

    cupcakes_os_card_end

    printf '\n'
    cupcakes_os_dim_line "Run 'cupcakes-os config set <key> <value>' to change a setting."
    cupcakes_os_dim_line "Run 'cupcakes-os config apply' to rebuild after changes."
    printf '\n'
}

# ── Set ───────────────────────────────────────────────────────────────────────

valid_desktops=(
    none gnome plasma hyprland sway xfce cinnamon mate budgie lxqt pantheon
    i3 awesome openbox niri river qtile bspwm fluxbox
    icewm herbstluftwm cosmic mangowm
)

wallpaper_candidates() {
    if [[ -d "$wallpaper_dir" ]]; then
        find "$wallpaper_dir" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort
        return 0
    fi

    printf '%s\n' \
        Daytime-MNT.jpg \
        NightTime-MNT.png \
        oceandusk.png \
        bluehorizon.png \
        astronautwallpaper.png \
        glacierreflection.png
}

validate_wallpaper() {
    local candidate="$1"
    if wallpaper_candidates | grep -Fxq "$candidate"; then
        return 0
    fi

    cupcakes_os_error "Unknown wallpaper: '${candidate}'"
    printf '  %bAvailable wallpapers:%b\n' "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC"
    wallpaper_candidates | sed 's/^/    /'
    printf '\n'
    exit 1
}

validate_desktop() {
    local d="$1"
    for valid in "${valid_desktops[@]}"; do
        [[ "$d" == "$valid" ]] && return 0
    done
    cupcakes_os_error "Unknown desktop: '${d}'"
    printf '  %bValid options:%b %s\n\n' "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC" "${valid_desktops[*]}"
    exit 1
}

safe_timezone() {
    [[ "$1" =~ ^[A-Za-z0-9_+./-]+$ && "$1" != *..* && "$1" != /* ]]
}

safe_xkb_code() {
    [[ "$1" =~ ^[a-z]{2,3}(,[a-z]{2,3})*$ ]]
}

do_set() {
    local key="$1" value="$2"

    require_local_module
    require_options_format

    # Belt-and-suspenders: no settable value may contain characters that could
    # break out of the Nix double-quoted string it gets written into ('"' ends
    # the string; '\' starts an escape; '${' begins Nix antiquotation), no
    # matter which key-specific check below runs.
    if [[ "$value" == *'"'* || "$value" == *'\'* || "$value" == *'${'* ]]; then
        cupcakes_os_error "Invalid value '${value}' — it cannot contain '\"', '\\', or '\${'."
        exit 1
    fi

    # Validate and normalise the key.
    case "$key" in
        hostname)
            if [[ ! "$value" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
                cupcakes_os_error "Invalid hostname '${value}' — use letters, numbers, and hyphens only."
                exit 1
            fi
            ;;
        timezone)
            if ! safe_timezone "$value"; then
                cupcakes_os_error "Invalid timezone '${value}' — expected a zoneinfo-style name (e.g. 'America/New_York')."
                exit 1
            fi
            ;;
        keyboard | keyboard.console)
            key="keyboard.console"
            ;;
        keyboard.xkb)
            if ! safe_xkb_code "$value"; then
                cupcakes_os_error "Invalid keyboard layout '${value}' — expected a layout code (e.g. 'us' or 'us,de')."
                exit 1
            fi
            ;;
        desktop)
            validate_desktop "$value"
            ;;
        wallpaper)
            validate_wallpaper "$value"
            ;;
        *)
            cupcakes_os_error "Unknown key: '${key}'"
            printf '  %bSettable keys:%b  hostname  timezone  keyboard  keyboard.xkb  desktop  wallpaper\n\n' \
                "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC"
            exit 1
            ;;
    esac

    # Write the new value — one sed pass, works for all keys.
    local escaped_key="${key//./\\.}"
    run_as_root sed -i -E \
        "s|^([[:space:]]*cupcakes-os\\.${escaped_key}[[:space:]]*=[[:space:]]*)\"[^\"]*\";|\\1\"${value}\";|" \
        "$local_module"

    cupcakes_os_success "'cupcakes-os.${key}' set to '${value}'"
    cupcakes_os_dim_line "Run 'cupcakes-os config apply' to rebuild the system."
    printf '\n'
}

# ── Apply ─────────────────────────────────────────────────────────────────────

do_apply() {
    local flake_target="${CUPCAKES_OS_FLAKE_CONFIG_NAME:-cupcakes-os}"

    require_local_module

    cupcakes_os_banner "Apply Configuration" "Rebuilding Cupcakes OS from ${local_module}"
    cupcakes_os_step "Running nixos-rebuild switch"
    printf '\n'

    run_as_root nixos-rebuild switch --flake "${config_dir}#${flake_target}"

    printf '\n'
    cupcakes_os_success "Done. Your changes are now active."
    printf '\n'
}

# ── Usage ─────────────────────────────────────────────────────────────────────

usage() {
    cupcakes_os_banner "Config" "View and edit your Cupcakes OS system settings."
    printf '  %bUsage%b\n\n' "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC"

    printf '  %bcupcakes-os config%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Show all current settings."
    printf '\n'

    printf '  %bcupcakes-os config set hostname   <value>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %bcupcakes-os config set timezone   <value>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %bcupcakes-os config set keyboard   <value>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %bcupcakes-os config set desktop    <value>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %bcupcakes-os config set wallpaper  <value>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Update a setting in cupcakes-os-local.nix."
    printf '\n'

    printf '  %bcupcakes-os config apply%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Rebuild the system to apply pending changes."
    printf '\n'

    printf '  %bSettable keys%b\n' "$CUPCAKES_OS_WHITE" "$CUPCAKES_OS_NC"
    printf '\n'
    cupcakes_os_dim_line "  hostname       Machine hostname (e.g. my-pc)"
    cupcakes_os_dim_line "  timezone       System timezone (e.g. America/New_York)"
    cupcakes_os_dim_line "  keyboard       Console keymap (e.g. us, de, fr)"
    cupcakes_os_dim_line "  keyboard.xkb   Graphical keyboard layout"
    cupcakes_os_dim_line "  desktop        Desktop environment (e.g. gnome, hyprland, plasma)"
    cupcakes_os_dim_line "  wallpaper      Shipped Cupcakes OS wallpaper filename"
    printf '\n'
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
    local command="${1:-}"

    case "$command" in
        "" | show)
            show_config
            ;;
        set)
            if [[ "${2:-}" == "" || "${3:-}" == "" ]]; then
                cupcakes_os_error "Usage: cupcakes-os config set <key> <value>"
                printf '\n'
                exit 1
            fi
            do_set "$2" "$3"
            ;;
        apply)
            do_apply
            ;;
        help | --help | -h)
            usage
            ;;
        *)
            cupcakes_os_error "Unknown command: ${command}"
            printf '\n'
            usage
            exit 1
            ;;
    esac
}

main "$@"
