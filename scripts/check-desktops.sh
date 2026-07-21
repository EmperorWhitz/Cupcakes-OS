#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$repo_dir"

# shellcheck source=/dev/null
source "$repo_dir/scripts/cupcakes-os-desktop-profiles.sh"

version="$(tr -d '\n' < "$repo_dir/VERSION")"
bootloader_background="$repo_dir/assets/bootloader/limine-background.png"
tmpdir="$(mktemp -d)"
staged_cupcakes-os="$tmpdir/cupcakes-os"
failed=0
pkgs_path=""
nix_cmd=(nix-instantiate)

if [[ -n "${CUPCAKES_OS_NIX_STORE:-}" ]]; then
  nix_cmd+=(--store "$CUPCAKES_OS_NIX_STORE")
fi

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

pass() {
  printf '[ok]   %s\n' "$1"
}

fail() {
  printf '[fail] %s\n' "$1"
  failed=1
}

resolve_nixpkgs_path() {
  if [[ -n "${CUPCAKES_OS_NIXPKGS_PATH:-}" && -d "${CUPCAKES_OS_NIXPKGS_PATH:-}" ]]; then
    printf '%s\n' "$CUPCAKES_OS_NIXPKGS_PATH"
    return 0
  fi

  if "${nix_cmd[@]}" --find-file nixpkgs 2>/dev/null; then
    return 0
  fi

  if command -v nix >/dev/null 2>&1; then
    nix --extra-experimental-features "nix-command flakes" \
      eval --raw --impure \
      --expr "(builtins.getFlake \"path:${repo_dir}\").inputs.nixpkgs.outPath" 2>/dev/null
  fi
}

assert_supported_everywhere() {
  local profile="$1"
  local file
  for file in \
    "$repo_dir/scripts/anix.sh" \
    "$repo_dir/scripts/cupcakes-os-config.sh" \
    "$repo_dir/nix/modules/cupcakes-os-options.nix" \
    "$repo_dir/nix/modules/anix.nix"; do
    if ! grep -Eq "\"?${profile}\"?([[:space:]]|$)" "$file"; then
      fail "desktop list missing ${profile}: ${file#$repo_dir/}"
    fi
  done
}

if ! pkgs_path="$(resolve_nixpkgs_path)"; then
  printf 'No nixpkgs source is available. Set CUPCAKES_OS_NIXPKGS_PATH or NIX_PATH.\n' >&2
  exit 1
fi

stage_installed_cupcakes-os() {
  mkdir -p \
    "$staged_cupcakes-os/bootloader" \
    "$staged_cupcakes-os/desktops" \
    "$staged_cupcakes-os/effects" \
    "$staged_cupcakes-os/mango" \
    "$staged_cupcakes-os/pkgs" \
    "$staged_cupcakes-os/plymouth" \
    "$staged_cupcakes-os/themes" \
    "$staged_cupcakes-os/wallpapers"

  cp "$repo_dir/VERSION" "$staged_cupcakes-os/VERSION"
  cp "$repo_dir/assets/cupcakes-os-title.txt" "$staged_cupcakes-os/title.txt"
  cp "$repo_dir/assets/fastfetch-logo.txt" "$staged_cupcakes-os/fastfetch-logo.txt"
  cp "$repo_dir/assets/fastfetch-config.jsonc" "$staged_cupcakes-os/fastfetch-config.jsonc"
  cp "$repo_dir/assets/cupcakes-os-logo.png" "$staged_cupcakes-os/cupcakes-os-logo.png"
  cp "$repo_dir/assets/wallpapers/collection/Daytime-MNT.jpg" "$staged_cupcakes-os/default-wallpaper.png"
  cp "$repo_dir/assets/mango/config.conf" "$staged_cupcakes-os/mango/config.conf"
  cp "$repo_dir/assets/plymouth/cupcakes-os.plymouth" "$staged_cupcakes-os/plymouth/cupcakes-os.plymouth"
  cp "$repo_dir/assets/plymouth/cupcakes-os.script" "$staged_cupcakes-os/plymouth/cupcakes-os.script"
  cp "$repo_dir/assets/Effects/v3StartingCupcakes-OS.mp3" "$staged_cupcakes-os/effects/v3StartingCupcakes-OS.mp3"
  cp "$repo_dir"/assets/bootloader/* "$staged_cupcakes-os/bootloader/"
  cp "$repo_dir"/assets/wallpapers/collection/* "$staged_cupcakes-os/wallpapers/"
  cp "$repo_dir"/assets/wallpaper-themes/* "$staged_cupcakes-os/themes/"

  cp "$repo_dir/nix/modules/installed-base.nix" "$staged_cupcakes-os/installed-base.nix"
  cp "$repo_dir/nix/modules/cupcakes-os-options.nix" "$staged_cupcakes-os/cupcakes-os-options.nix"
  cp "$repo_dir/nix/modules/anix.nix" "$staged_cupcakes-os/anix-module.nix"
  cp -R "$repo_dir/nix/modules/desktops/." "$staged_cupcakes-os/desktops/"
  cp "$repo_dir/nix/pkgs/mango.nix" "$staged_cupcakes-os/pkgs/mango.nix"
  cp "$repo_dir/nix/pkgs/modularity.nix" "$staged_cupcakes-os/pkgs/modularity.nix"

  cp "$repo_dir/scripts/cupcakes-os-ui.sh" "$staged_cupcakes-os/ui.sh"
  cp "$repo_dir/scripts/cupcakes-os-config.sh" "$staged_cupcakes-os/config.sh"
  cp "$repo_dir/scripts/cupcakes-os.sh" "$staged_cupcakes-os/cupcakes-os.sh"
  cp "$repo_dir/scripts/cupcakes-os-desktop.sh" "$staged_cupcakes-os/desktop.sh"
  cp "$repo_dir/scripts/cupcakes-os-doctor.sh" "$staged_cupcakes-os/doctor.sh"
  cp "$repo_dir/scripts/cupcakes-os-check-full.sh" "$staged_cupcakes-os/check-full.sh"
  cp "$repo_dir/scripts/cupcakes-os-recovery.sh" "$staged_cupcakes-os/recovery.sh"
  cp "$repo_dir/scripts/cupcakes-os-welcome.sh" "$staged_cupcakes-os/welcome.sh"
  cp "$repo_dir/scripts/anix.sh" "$staged_cupcakes-os/anix.sh"
  cp "$repo_dir/scripts/cupcakes-os-app-catalog.sh" "$staged_cupcakes-os/app-catalog.sh"
  cp "$repo_dir/scripts/cupcakes-os-apps.sh" "$staged_cupcakes-os/apps.sh"
  cp "$repo_dir/scripts/cupcakes-os-support-report.sh" "$staged_cupcakes-os/support-report.sh"
  cp "$repo_dir/scripts/cupcakes-os-hardware-test.sh" "$staged_cupcakes-os/hardware-test.sh"
  cp "$repo_dir/scripts/cupcakes-os-desktop-profiles.sh" "$staged_cupcakes-os/desktop-profiles.sh"
  cp "$repo_dir/scripts/cupcakes-os-installer.sh" "$staged_cupcakes-os/installer.sh"
  cp "$repo_dir/scripts/cupcakes-os-setup-launcher.sh" "$staged_cupcakes-os/setup-launcher.sh"
  cp "$repo_dir/scripts/cupcakes-os-setup.desktop" "$staged_cupcakes-os/setup.desktop"
  cp "$repo_dir/scripts/cupcakes-os-session-setup.sh" "$staged_cupcakes-os/session-setup.sh"
  cp "$repo_dir/scripts/cupcakes-os-theme-sync.sh" "$staged_cupcakes-os/theme-sync.sh"
  cp "$repo_dir/scripts/cupcakes-os-update.sh" "$staged_cupcakes-os/update.sh"
  cp -R "$repo_dir/vendor/tinypm" "$staged_cupcakes-os/tinypm"
}

stage_installed_cupcakes-os

while IFS= read -r desktop_profile; do
  desktop_label=""
  desktop_variant_id=""
  cupcakes_os_sync_desktop_label "$desktop_profile"
  desktop_block="$(cupcakes_os_desktop_config_block "$desktop_profile" "us" "cupcakes-os" "$(cupcakes_os_default_wallpaper_uri)")"
  desktop_packages="$(cupcakes_os_desktop_package_block "$desktop_profile")"

  assert_supported_everywhere "$desktop_profile"

  cat > "$tmpdir/${desktop_profile}.nix" <<EOF
let
  pkgsPath = ${pkgs_path};
  evalConfig = import (pkgsPath + "/nixos/lib/eval-config.nix");
  installedBase = import ${staged_cupcakes-os}/installed-base.nix;
  desktopModule = { pkgs, lib, ... }: {
    system.nixos.variantName = "Cupcakes OS ${version} ${desktop_label} Edition";
    system.nixos.variant_id = "${desktop_variant_id}";

    networking.hostName = "cupcakes-os-${desktop_profile}";
    time.timeZone = "UTC";
    console.keyMap = "us";

    fileSystems."/" = {
      device = "/dev/disk/by-label/CUPCAKES_OS_ROOT";
      fsType = "ext4";
    };
    fileSystems."/boot" = {
      device = "/dev/disk/by-label/CUPCAKE_EFI";
      fsType = "vfat";
    };

    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.limine = {
      enable = true;
      biosSupport = true;
      biosDevice = "/dev/vda";
      efiSupport = true;
      efiInstallAsRemovable = true;
      style.wallpapers = [ ${bootloader_background} ];
    };

${desktop_block}
    users.users.cupcakes-os = {
      isNormalUser = true;
      description = "Cupcakes OS User";
      createHome = true;
      extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
      hashedPassword = "!";
    };

    security.sudo.wheelNeedsPassword = true;

    environment.systemPackages = with pkgs; [
${desktop_packages}
    ];

    system.stateVersion = "26.05";
  };
  config = (evalConfig {
    system = "x86_64-linux";
    modules = [ installedBase desktopModule ];
  }).config;
in
  {
    inherit (config.system.nixos) variantName variant_id;
    defaultSession = config.services.displayManager.defaultSession or null;
    toplevel = config.system.build.toplevel.drvPath;
  }
EOF
done < <(cupcakes_os_supported_desktop_profiles)

while IFS= read -r desktop_profile; do
  printf '[..]  instantiating: %s\n' "$desktop_profile"
  if "${nix_cmd[@]}" --eval --strict "$tmpdir/${desktop_profile}.nix" >/dev/null 2>&1; then
    pass "desktop toplevel: ${desktop_profile}"
  else
    fail "desktop toplevel: ${desktop_profile}"
    "${nix_cmd[@]}" --eval --strict "$tmpdir/${desktop_profile}.nix" || true
  fi
done < <(cupcakes_os_supported_desktop_profiles)

if [[ "$failed" -ne 0 ]]; then
  printf '\nOne or more desktop checks failed.\n' >&2
  exit 1
fi

printf '\nAll desktop checks passed.\n'
