#!/usr/bin/env bash
set -euo pipefail

export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ui_lib="${CUPCAKES_OS_UI_LIB:-$script_dir/cupcakes-os-ui.sh}"
[[ ! -f "$ui_lib" && -f /etc/cupcakes-os/ui.sh ]] && ui_lib="/etc/cupcakes-os/ui.sh"

# shellcheck source=/dev/null
source "$ui_lib"

run_cmd() {
    printf '\n'
    cupcakes_os_step "$*"
    "$@"
}

menu() {
    cupcakes_os_banner "Recovery" "Rollback, repair, and collect diagnostics."
    printf '  %b1%b  Roll back previous generation\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %b2%b  Run support report\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %b3%b  Repair Flathub remote\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %b4%b  Rebuild current config\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %b5%b  Run ANIX doctor\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %b6%b  Run Cupcakes OS doctor\n' "$CUPCAKES_OS_CYAN" "$CUPCAKES_OS_NC"
    printf '  %bq%b  Quit\n\n' "$CUPCAKES_OS_DIM" "$CUPCAKES_OS_NC"
}

repair_flathub() {
    if ! command -v flatpak >/dev/null 2>&1; then
        cupcakes_os_error "flatpak is not installed."
        return 1
    fi
    run_cmd flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

rebuild_current() {
    run_cmd sudo nixos-rebuild switch --flake /etc/nixos#cupcakes-os
}

case "${1:-menu}" in
    rollback)
        run_cmd anix rollback nix --now
        ;;
    report)
        run_cmd cupcakes-os-support-report
        ;;
    flathub)
        repair_flathub
        ;;
    rebuild)
        rebuild_current
        ;;
    anix)
        run_cmd anix doctor
        ;;
    doctor)
        run_cmd cupcakes-os-doctor
        ;;
    menu|"")
        while true; do
            menu
            read -r -p "  Choose: " choice
            case "$choice" in
                1) run_cmd anix rollback nix --now ;;
                2) run_cmd cupcakes-os-support-report ;;
                3) repair_flathub ;;
                4) rebuild_current ;;
                5) run_cmd anix doctor ;;
                6) run_cmd cupcakes-os-doctor ;;
                q|Q) exit 0 ;;
                *) cupcakes_os_warn "Unknown choice: $choice" ;;
            esac
            printf '\n'
            read -r -p "  Press Enter to continue..." _
        done
        ;;
    help|--help|-h)
        cupcakes_os_banner "Recovery" "Usage: cupcakes-os recovery [rollback|report|flathub|rebuild|anix|doctor]"
        ;;
    *)
        cupcakes_os_error "Unknown recovery command: $1"
        exit 1
        ;;
esac
