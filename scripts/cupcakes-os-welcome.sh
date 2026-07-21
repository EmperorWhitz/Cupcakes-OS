#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ui_lib="${CUPCAKES_OS_UI_LIB:-$script_dir/cupcakes-os-ui.sh}"
[[ ! -f "$ui_lib" && -f /etc/cupcakes-os/ui.sh ]] && ui_lib="/etc/cupcakes-os/ui.sh"

# shellcheck source=/dev/null
source "$ui_lib"

read_setting() {
    local key="$1"
    local escaped_key="${key//./\\.}"
    local file="${CUPCAKES_OS_SYSTEM_CONFIG:-/etc/nixos}/cupcakes-os-local.nix"
    [[ -f "$file" ]] || return 0
    sed -nE "s|^[[:space:]]*cupcakes-os\\.${escaped_key}[[:space:]]*=[[:space:]]*\"([^\"]+)\";.*|\\1|p" "$file" | head -n1
}

show_status() {
    local desktop wallpaper channel flathub anix_state
    desktop="$(read_setting desktop)"
    wallpaper="$(read_setting wallpaper)"
    channel="stable"
    [[ -f /etc/nixos/cupcakes-os/channel ]] && channel="$(tr -d '[:space:]' < /etc/nixos/cupcakes-os/channel)"
    flathub="not configured"
    if command -v flatpak >/dev/null 2>&1 && flatpak remotes --system 2>/dev/null | awk '{print $1}' | grep -Fxq flathub; then
        flathub="configured"
    fi
    anix_state="ready"
    [[ -f /etc/nixos/anix.nix ]] || anix_state="not initialized"

    cupcakes_os_card_start "System"
    cupcakes_os_kv "desktop" "${desktop:-unknown}"
    cupcakes_os_kv "wallpaper" "${wallpaper:-unknown}"
    cupcakes_os_kv "updates" "$channel"
    cupcakes_os_kv "Flathub" "$flathub"
    cupcakes_os_kv "ANIX" "$anix_state"
    cupcakes_os_card_end
}

menu() {
    cupcakes_os_banner "Welcome To Cupcakes OS" "A few useful first steps."
    show_status
    printf '\n'
    printf '  %b1%b  Run system doctor\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %b2%b  Open app manager\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %b3%b  Create first ANIX snapshot\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %b4%b  Switch desktop\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %b5%b  Open recovery tools\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %bq%b  Quit\n\n' "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC"
}

case "${1:-menu}" in
    status)
        cupcakes_os_banner "Welcome To Cupcakes OS" "Current system status."
        show_status
        printf '\n'
        ;;
    menu|"")
        while true; do
            menu
            read -r -p "  Choose: " choice
            case "$choice" in
                1) cupcakes-os-doctor ;;
                2) cupcakes-os-apps ;;
                3) anix save "anix: first Cupcakes OS snapshot" ;;
                4) cupcakes-os-desktop list ;;
                5) cupcakes-os-recovery ;;
                q|Q) exit 0 ;;
                *) cupcakes_os_warn "Unknown choice: $choice" ;;
            esac
            printf '\n'
            read -r -p "  Press Enter to continue..." _
        done
        ;;
    help|--help|-h)
        cupcakes_os_banner "Welcome" "Usage: cupcakes-os-welcome [status]"
        ;;
    *)
        cupcakes_os_error "Unknown welcome command: $1"
        exit 1
        ;;
esac
