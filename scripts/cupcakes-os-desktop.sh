#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ui_lib="${CUPCAKES_OS_UI_LIB:-$script_dir/cupcakes-os-ui.sh}"
profiles_lib="${CUPCAKES_OS_DESKTOP_PROFILES_LIB:-$script_dir/cupcakes-os-desktop-profiles.sh}"

[[ ! -f "$ui_lib" && -f /etc/cupcakes-os/ui.sh ]] && ui_lib="/etc/cupcakes-os/ui.sh"
[[ ! -f "$profiles_lib" && -f /etc/cupcakes-os/desktop-profiles.sh ]] && profiles_lib="/etc/cupcakes-os/desktop-profiles.sh"

# shellcheck source=/dev/null
source "$ui_lib"
# shellcheck source=/dev/null
source "$profiles_lib"

run_config() {
    if command -v cupcakes-os-config >/dev/null 2>&1; then
        cupcakes-os-config "$@"
    else
        CUPCAKES_OS_UI_LIB="$ui_lib" bash "$script_dir/cupcakes-os-config.sh" "$@"
    fi
}

usage() {
    cupcakes_os_banner "Desktop" "View or switch Cupcakes OS desktop profiles."
    printf '  %bcupcakes-os desktop%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Show current desktop setting."
    printf '\n'
    printf '  %bcupcakes-os desktop list%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  List supported desktop profiles."
    printf '\n'
    printf '  %bcupcakes-os desktop set <profile>%b\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    cupcakes_os_dim_line "  Change the desktop profile; rebuild with 'cupcakes-os config apply'."
    printf '\n'
}

case "${1:-show}" in
    show|"")
        run_config
        ;;
    list)
        cupcakes_os_banner "Desktop Profiles" "These names work with 'cupcakes-os desktop set <profile>'."
        cupcakes_os_card_start "Supported Profiles"
        cupcakes_os_supported_desktop_profiles | while IFS= read -r profile; do
            cupcakes_os_sync_desktop_label "$profile"
            printf '  %b│%b  %b%-16s%b %b%s%b\n' \
                "$CUPCAKES_OS_BLUE" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_CYAN" "$profile" "$CUPCAKES_OS_NC" "$CUPCAKES_OS_DIM" "$desktop_label" "$CUPCAKES_OS_NC"
        done
        cupcakes_os_card_end
        printf '\n'
        ;;
    set)
        profile="${2:-}"
        if [[ -z "$profile" ]]; then
            cupcakes_os_error "Usage: cupcakes-os desktop set <profile>"
            exit 1
        fi
        if ! cupcakes_os_supported_desktop_profiles | grep -Fxq "$profile"; then
            cupcakes_os_error "Unknown desktop profile: $profile"
            exit 1
        fi
        run_config set desktop "$profile"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        cupcakes_os_error "Unknown desktop command: $1"
        usage
        exit 1
        ;;
esac
