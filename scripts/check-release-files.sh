#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$repo_dir"

required_paths() {
    cat <<'EOF'
VERSION
nix/modules/cupcakes-os-options.nix
nix/modules/installed-base.nix
nix/modules/anix.nix
nix/modules/desktops
nix/pkgs/mango.nix
nix/pkgs/modularity.nix
scripts/cupcakes-os-update.sh
scripts/cupcakes-os-installer.sh
scripts/cupcakes-os-repair-flake-purity.sh
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
assets/mango/config.conf
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
}

missing=0
while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    if [[ ! -e "$path" ]]; then
        printf 'missing required release file: %s\n' "$path" >&2
        missing=1
    fi
done < <(required_paths)

if [[ "$missing" -ne 0 ]]; then
    printf 'Release file check failed. Do not tag or ship this checkout.\n' >&2
    exit 1
fi

printf 'All updater-required release files are present.\n'
