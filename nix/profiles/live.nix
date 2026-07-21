{ lib, pkgs, version, liveEdition ? "cosmic", ... }:
let
  liveEditions = {
    cosmic = {
      id = "cosmic";
      label = "COSMIC Edition";
      desktop = "cosmic";
      session = "cosmic";
    };
    hyprland = {
      id = "hyprland";
      label = "Hyprland Edition";
      desktop = "hyprland";
      session = "hyprland-uwsm";
    };
    gnome = {
      id = "gnome";
      label = "GNOME Edition";
      desktop = "gnome";
      session = "gnome";
    };
    kde = {
      id = "kde";
      label = "KDE Plasma Edition";
      desktop = "plasma";
      session = "plasma";
    };
    other = {
      id = "other";
      label = "Other Desktops Edition";
      desktop = "mangowm";
      session = "mango";
    };
  };
  selectedEdition =
    if builtins.hasAttr liveEdition liveEditions
    then builtins.getAttr liveEdition liveEditions
    else liveEditions.cosmic;

  cupcakesOsApps = pkgs.writeShellScriptBin "cupcakes-os-apps" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/apps.sh "$@"
  '';
  cupcakesOsConfig = pkgs.writeShellScriptBin "cupcakes-os-config" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/config.sh "$@"
  '';
  cupcakesOsCommand = pkgs.writeShellScriptBin "cupcakes-os" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/cupcakes-os.sh "$@"
  '';
  cupcakesOsDesktop = pkgs.writeShellScriptBin "cupcakes-os-desktop" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/desktop.sh "$@"
  '';
  cupcakesOsDotfilesImport = pkgs.writeShellScriptBin "cupcakes-os-dotfiles-import" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/dotfiles-import.sh "$@"
  '';
  cupcakesOsDoctor = pkgs.writeShellScriptBin "cupcakes-os-doctor" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/doctor.sh "$@"
  '';
  cupcakesOsCheckFull = pkgs.writeShellScriptBin "cupcakes-os-check-full" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/check-full.sh "$@"
  '';
  cupcakesOsRecovery = pkgs.writeShellScriptBin "cupcakes-os-recovery" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/recovery.sh "$@"
  '';
  cupcakesOsWelcome = pkgs.writeShellScriptBin "cupcakes-os-welcome" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/welcome.sh "$@"
  '';
  anixCommand = pkgs.writeShellScriptBin "anix" ''
    exec env ANIX_SYSTEM_CONFIG=/etc/nixos ANIX_FLAKE_CONFIG_NAME=cupcakes-os ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/anix.sh "$@"
  '';
  cupcakesOsSupportReport = pkgs.writeShellScriptBin "cupcakes-os-support-report" ''
    exec ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/support-report.sh "$@"
  '';
  cupcakesOsHardwareTest = pkgs.writeShellScriptBin "cupcakes-os-hardware-test" ''
    exec env CUPCAKES_OS_SUPPORT_REPORT_SCRIPT=/etc/cupcakes-os/support-report.sh ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/hardware-test.sh "$@"
  '';
  cupcakesOsInstall = pkgs.writeShellScriptBin "cupcakes-os-install" ''
    if [ "$(id -u)" -ne 0 ]; then
      sudo_bin=/run/wrappers/bin/sudo
      if [ ! -x "$sudo_bin" ]; then
        sudo_bin=sudo
      fi
      exec "$sudo_bin" \
        TERM="''${TERM:-linux}" \
        CUPCAKES_OS_DESKTOP_PROFILES_LIB=/etc/cupcakes-os/desktop-profiles.sh \
        CUPCAKES_OS_APP_CATALOG_LIB=/etc/cupcakes-os/app-catalog.sh \
        ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/installer.sh "$@"
    fi
    exec env \
      TERM="''${TERM:-linux}" \
      CUPCAKES_OS_DESKTOP_PROFILES_LIB=/etc/cupcakes-os/desktop-profiles.sh \
      CUPCAKES_OS_APP_CATALOG_LIB=/etc/cupcakes-os/app-catalog.sh \
      ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/installer.sh "$@"
  '';
  cupcakesOsSetup = pkgs.writeShellScriptBin "cupcakes-os-setup" ''
    exec env CUPCAKES_OS_INSTALLER=/etc/cupcakes-os/installer.sh \
      CUPCAKES_OS_SETUP_MODE=install \
      ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/setup-launcher.sh "$@"
  '';
  cupcakesOsSetupDesktopPkg = pkgs.runCommandLocal "cupcakes-os-setup-desktop" { } ''
    mkdir -p "$out/share/applications"
    cp ${../../scripts/cupcakes-os-setup.desktop} "$out/share/applications/cupcakes-os-setup.desktop"
  '';
  cupcakesOsUpdate = pkgs.writeShellScriptBin "cupcakes-os-update" ''
    exec env CUPCAKES_OS_UPDATE_COMMAND=cupcakes-os-update ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/update.sh "$@"
  '';
  cupcakesOsSessionSetup = pkgs.writeShellScriptBin "cupcakes-os-session-setup" ''
    exec env CUPCAKES_OS_GSETTINGS_BIN=${pkgs.glib}/bin/gsettings CUPCAKES_OS_THEME_SYNC_SCRIPT=/etc/cupcakes-os/theme-sync.sh ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/session-setup.sh "$@"
  '';
  cupcakesOsThemeSync = pkgs.writeShellScriptBin "cupcakes-os-theme-sync" ''
    exec env CUPCAKES_OS_GSETTINGS_BIN=${pkgs.glib}/bin/gsettings ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/theme-sync.sh "$@"
  '';
  nixosCommand = pkgs.writeShellScriptBin "nixos" ''
    exec env CUPCAKES_OS_UPDATE_COMMAND=nixos ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/update.sh "$@"
  '';
  updateCommand = pkgs.writeShellScriptBin "update" ''
    exec env CUPCAKES_OS_UPDATE_COMMAND=update ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/update.sh "$@"
  '';
  upgradeCommand = pkgs.writeShellScriptBin "upgrade" ''
    exec env CUPCAKES_OS_UPDATE_COMMAND=upgrade ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/update.sh "$@"
  '';
  rollbackCommand = pkgs.writeShellScriptBin "rollback" ''
    exec env CUPCAKES_OS_UPDATE_COMMAND=rollback ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/update.sh "$@"
  '';
  cupcakes-osGrubTheme = pkgs.runCommandLocal "cupcakes-os-grub-theme" { } ''
    mkdir -p "$out"
    cp -r ${pkgs.nixos-grub2-theme}/* "$out/"
    chmod -R u+w "$out"
    cp ${../../assets/bootloader/background.png} "$out/background.png"
    cp ${../../assets/bootloader/theme.txt} "$out/theme.txt"
  '';
  cupcakes-osPlymouthTheme = pkgs.runCommandLocal "cupcakes-os-plymouth-theme" { } ''
    mkdir -p "$out/share/plymouth/themes/cupcakes-os"
    cp ${../../assets/plymouth/cupcakes-os.plymouth} "$out/share/plymouth/themes/cupcakes-os/cupcakes-os.plymouth"
    cp ${../../assets/plymouth/cupcakes-os.script} "$out/share/plymouth/themes/cupcakes-os/cupcakes-os.script"
  '';
  wallpaperDir = ../../assets/wallpapers/collection;
  wallpaperThemeDir = ../../assets/wallpaper-themes;
  tinypmDir = ../../vendor/tinypm;
  cupcakesOsInstallerGui =
    let
      python = pkgs.python3.withPackages (ps: with ps; [ pygobject3 ]);
      giPath = lib.makeSearchPath "lib/girepository-1.0" (with pkgs; [
        gtk4 libadwaita glib gdk-pixbuf (lib.getLib pango) harfbuzz graphene cairo gobject-introspection
      ]);
      libPath = lib.makeLibraryPath (with pkgs; [
        gtk4 libadwaita glib gdk-pixbuf cairo
      ]);
    in
    pkgs.writeShellScriptBin "cupcakes-os-installer-gui" ''
      export GI_TYPELIB_PATH="${giPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
      export LD_LIBRARY_PATH="${libPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      export CUPCAKES_OS_INSTALLER="''${CUPCAKES_OS_INSTALLER:-/etc/cupcakes-os/installer.sh}"
      export CUPCAKES_OS_DEFAULT_DESKTOP="''${CUPCAKES_OS_DEFAULT_DESKTOP:-${selectedEdition.desktop}}"
      export CUPCAKES_OS_EDITION="''${CUPCAKES_OS_EDITION:-${selectedEdition.id}}"
      # Force software renderer so the installer works in QEMU and on
      # hardware without accelerated GL (black window otherwise).
      export GSK_RENDERER="''${GSK_RENDERER:-cairo}"
      export GDK_BACKEND="''${GDK_BACKEND:-wayland,x11}"
      exec ${python}/bin/python3 /etc/cupcakes-os/installer-gui.py "$@"
    '';
  cupcakes-osWallpapersPackage = pkgs.runCommandLocal "cupcakes-os-wallpapers" { } ''
    mkdir -p "$out/share/backgrounds/cupcakes-os" "$out/share/cupcakes-os/themes" "$out/share/gnome-background-properties"
    find ${wallpaperDir} -maxdepth 1 -type f -exec cp {} "$out/share/backgrounds/cupcakes-os/" \;
    find ${wallpaperThemeDir} -maxdepth 1 -type f -exec cp {} "$out/share/cupcakes-os/themes/" \;
    cat >"$out/share/gnome-background-properties/cupcakes-os.xml" <<'EOF'
    <?xml version="1.0"?>
    <!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
    <wallpapers>
      <wallpaper deleted="false">
        <name>Cupcakes OS Dark</name>
        <filename>/run/current-system/sw/share/backgrounds/cupcakes-os/cupcakes-os-dark.svg</filename>
        <filename-dark>/run/current-system/sw/share/backgrounds/cupcakes-os/cupcakes-os-dark.svg</filename-dark>
        <options>zoom</options>
        <shade_type>solid</shade_type>
        <pcolor>#030812</pcolor>
        <scolor>#030812</scolor>
      </wallpaper>
      <wallpaper deleted="false">
        <name>Cupcakes OS Light</name>
        <filename>/run/current-system/sw/share/backgrounds/cupcakes-os/cupcakes-os-light.svg</filename>
        <filename-dark>/run/current-system/sw/share/backgrounds/cupcakes-os/cupcakes-os-dark.svg</filename-dark>
        <options>zoom</options>
        <shade_type>solid</shade_type>
        <pcolor>#f2f9fe</pcolor>
        <scolor>#030812</scolor>
      </wallpaper>
      <wallpaper deleted="false">
        <name>Mountain (Day/Night)</name>
        <filename>/run/current-system/sw/share/backgrounds/cupcakes-os/Daytime-MNT.jpg</filename>
        <filename-dark>/run/current-system/sw/share/backgrounds/cupcakes-os/NightTime-MNT.png</filename-dark>
        <options>zoom</options>
        <shade_type>solid</shade_type>
        <pcolor>#1a2a1a</pcolor>
        <scolor>#0a0e1a</scolor>
      </wallpaper>
      <wallpaper deleted="false">
        <name>Ocean Dusk</name>
        <filename>/run/current-system/sw/share/backgrounds/cupcakes-os/oceandusk.png</filename>
        <filename-dark>/run/current-system/sw/share/backgrounds/cupcakes-os/oceandusk.png</filename-dark>
        <options>zoom</options>
        <shade_type>solid</shade_type>
        <pcolor>#07111f</pcolor>
        <scolor>#07111f</scolor>
      </wallpaper>
      <wallpaper deleted="false">
        <name>Blue Horizon</name>
        <filename>/run/current-system/sw/share/backgrounds/cupcakes-os/bluehorizon.png</filename>
        <filename-dark>/run/current-system/sw/share/backgrounds/cupcakes-os/bluehorizon.png</filename-dark>
        <options>zoom</options>
        <shade_type>solid</shade_type>
        <pcolor>#081223</pcolor>
        <scolor>#081223</scolor>
      </wallpaper>
      <wallpaper deleted="false">
        <name>Astronaut Wallpaper</name>
        <filename>/run/current-system/sw/share/backgrounds/cupcakes-os/astronautwallpaper.png</filename>
        <filename-dark>/run/current-system/sw/share/backgrounds/cupcakes-os/astronautwallpaper.png</filename-dark>
        <options>zoom</options>
        <shade_type>solid</shade_type>
        <pcolor>#0b1020</pcolor>
        <scolor>#0b1020</scolor>
      </wallpaper>
      <wallpaper deleted="false">
        <name>Glacier Reflection</name>
        <filename>/run/current-system/sw/share/backgrounds/cupcakes-os/glacierreflection.png</filename>
        <filename-dark>/run/current-system/sw/share/backgrounds/cupcakes-os/glacierreflection.png</filename-dark>
        <options>zoom</options>
        <shade_type>solid</shade_type>
        <pcolor>#0b1625</pcolor>
        <scolor>#0b1625</scolor>
      </wallpaper>
    </wallpapers>
    EOF
  '';
  mkGrabCmd = name: pkgs.writeShellScriptBin name ''
    exec env TINYPM_FLAVOR=cupcakes-os ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/tinypm/${name} "$@"
  '';
in
{
  system.stateVersion = "26.05";
  nixpkgs.config.allowUnfree = true;
  networking.hostName = "cupcakes-os";
  # NetworkManager manages wpa_supplicant over D-Bus; do not force
  # networking.wireless.enable off or Wi-Fi will never come up.
  networking.networkmanager = {
    enable = lib.mkForce true;
    wifi.backend = "wpa_supplicant";
    wifi.powersave = false;
    ethernet.macAddress = "preserve";
    wifi.macAddress = "preserve";
  };
  services.dbus.packages = [ pkgs.wpa_supplicant ];
  networking.modemmanager.enable = true;
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  security.sudo.enable = true;
  security.polkit.enable = true;
  services.blueman.enable = true;
  services.dbus.enable = true;
  services.udisks2.enable = true;
  services.fwupd.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  services.printing.enable = true;
  hardware.sane.enable = true;

  # Flatpak powers COSMIC Store on the live image; Firefox ships natively too.
  services.flatpak.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  system.nixos.tags = [ "cupcakes-os" "nixos-base" ];
  system.nixos = {
    distroId = "cupcakes-os";
    distroName = "Cupcakes OS";
    vendorId = "cupcakes-os";
    vendorName = "Cupcakes OS";
    variant_id = "live";
    variantName = "Cupcakes OS ${selectedEdition.label} Live";
    label = version;
    extraOSReleaseArgs = {
      LOGO = "cupcakes-os";
      VERSION = "EVEREST 4.0";
      VERSION_ID = "4.0";
      VERSION_CODENAME = "denali";
      PRETTY_NAME = "Cupcakes OS EVEREST 4.0";
      HOME_URL = "https://www.cupcakesos.org/";
      SUPPORT_URL = "https://github.com/EmperorWhitz/cupcakes-os/issues";
      BUG_REPORT_URL = "https://github.com/EmperorWhitz/cupcakes-os/issues";
      ANSI_COLOR = "0;38;2;80;220;255";
    };
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-substitution-jobs = 32;
    http-connections = 128;
    max-jobs = "auto";
    cores = 0;
  };
  nix.nixPath = [
    "nixpkgs=${pkgs.path}"
    "nixos-config=/etc/nixos/configuration.nix"
  ];
  boot.kernelPackages = pkgs.linuxPackages_6_6;
  boot.initrd.systemd.enable = true;
  boot.initrd.verbose = false;
  boot.initrd.availableKernelModules = [
    "ahci"
    "ata_piix"
    "nvme"
    "sd_mod"
    "sr_mod"
    "usb_storage"
    "uas"
    "xhci_pci"
    "ehci_pci"
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "iwlwifi"
    "ath9k"
    "ath10k_pci"
    "ath11k_pci"
    "brcmfmac"
    "rtw88_pci"
    "rtw89_pci"
    "mt7921e"
  ];
  boot.kernelModules = [
    "btusb"
    "bluetooth"
    "iwlwifi"
    "ath9k"
    "ath10k_pci"
    "ath11k_pci"
    "brcmfmac"
    "rtw88_pci"
    "rtw89_pci"
    "mt7921e"
    "r8169"
    "e1000e"
    "igb"
    "tg3"
    "atlantic"
    "alx"
  ];
  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "loglevel=4"
    "udev.log_level=4"
    "rd.udev.log_level=4"
    "systemd.log_level=notice"
    "rd.systemd.log_level=notice"
    "systemd.show_status=true"
    "rd.systemd.show_status=true"
    "vt.global_cursor_default=1"
  ];
  boot.plymouth = {
    enable = true;
    theme = "cupcakes-os";
    themePackages = [ cupcakes-osPlymouthTheme ];
  };

  environment.systemPackages = (with pkgs; [
    # ── Cupcakes OS installer toolchain ────────────────────────────────────────────
    (mkGrabCmd "tinypm")
    (mkGrabCmd "tiny")
    (mkGrabCmd "Parcel")
    (mkGrabCmd "grab")
    (mkGrabCmd "search")
    (mkGrabCmd "term")
    (mkGrabCmd "start")
    (mkGrabCmd "supdate")
    cupcakesOsApps
    cupcakesOsCommand
    cupcakesOsCheckFull
    cupcakesOsInstall
    anixCommand
    cupcakesOsConfig
    cupcakesOsDesktop
    cupcakesOsDotfilesImport
    cupcakesOsDoctor
    cupcakesOsHardwareTest
    cupcakesOsRecovery
    cupcakesOsSessionSetup
    cupcakesOsSetup
    cupcakesOsSetupDesktopPkg
    cupcakesOsSupportReport
    cupcakesOsUpdate
    cupcakesOsWelcome
    cupcakes-osWallpapersPackage
    cupcakesOsThemeSync
    nixosCommand
    updateCommand
    upgradeCommand
    rollbackCommand

    # ── GUI installer ────────────────────────────────────────────────────────
    cupcakesOsInstallerGui
    cage        # kiosk Wayland compositor — lets the GUI installer run from TTY1

    # ── Shell / UI ───────────────────────────────────────────────────────────
    bashInteractive
    fastfetch   # shown in the live welcome banner
    gum         # charmbracelet TUI toolkit — used by the installer
    htop
    kdePackages.konsole
    newt        # provides nmtui for Wi-Fi setup
    xterm       # tiny fallback so the Start Cupcakes OS launcher can always open
    zenity      # graphical ANIX helper when launched from a desktop

    # ── Disk & filesystem ────────────────────────────────────────────────────
    dosfstools  # mkfs.vfat
    e2fsprogs   # mkfs.ext4
    parted
    util-linux  # wipefs, lsblk, mount …

    # ── Boot management ──────────────────────────────────────────────────────
    efibootmgr
    eject

    # ── Networking ───────────────────────────────────────────────────────────
    curl
    iproute2
    iputils
    iw
    networkmanager
    wget
    wpa_supplicant

    # ── Crypto / security ────────────────────────────────────────────────────
    openssl

    # ── Hardware inspection ──────────────────────────────────────────────────
    pciutils
    usbutils

    # ── Nix tooling (needed by nixos-install / flake ops) ───────────────────
    git
    xdg-utils

    # ── Live desktop apps ────────────────────────────────────────────────────
    firefox
    flatpak

    # ── Keyboard ─────────────────────────────────────────────────────────────
    kbd

  ]) ++ lib.optionals (selectedEdition.id == "other") (with pkgs; [
    mango
    foot
    waybar
    wofi
    icewm
    i3
    sway
  ]);

  environment.variables = {
    CUPCAKES_OS_VERSION = version;
    CUPCAKES_OS_NIXPKGS_PATH = pkgs.path;
    CUPCAKES_OS_ZONEINFO_PATH = "${pkgs.tzdata}/share/zoneinfo";
  };

  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
  };

  environment.etc =
    {
      "cupcakes-os/README".text = ''
        Cupcakes OS ${version} live image
        Base: Cupcakes OS
      '';
      "cupcakes-os/app-catalog.sh" = {
        source = ../../scripts/cupcakes-os-app-catalog.sh;
        mode = "0755";
      };
      "cupcakes-os/apps.sh" = {
        source = ../../scripts/cupcakes-os-apps.sh;
        mode = "0755";
      };
      "cupcakes-os/cupcakes-os.sh" = {
        source = ../../scripts/cupcakes-os.sh;
        mode = "0755";
      };
      "cupcakes-os/desktop.sh" = {
        source = ../../scripts/cupcakes-os-desktop.sh;
        mode = "0755";
      };
      "cupcakes-os/dotfiles-import.sh" = {
        source = ../../scripts/cupcakes-os-dotfiles-import.sh;
        mode = "0755";
      };
      "cupcakes-os/doctor.sh" = {
        source = ../../scripts/cupcakes-os-doctor.sh;
        mode = "0755";
      };
      "cupcakes-os/check-full.sh" = {
        source = ../../scripts/cupcakes-os-check-full.sh;
        mode = "0755";
      };
      "cupcakes-os/recovery.sh" = {
        source = ../../scripts/cupcakes-os-recovery.sh;
        mode = "0755";
      };
      "cupcakes-os/welcome.sh" = {
        source = ../../scripts/cupcakes-os-welcome.sh;
        mode = "0755";
      };
      "cupcakes-os/repair-flake-purity.sh" = {
        source = ../../scripts/cupcakes-os-repair-flake-purity.sh;
        mode = "0755";
      };
      "cupcakes-os/default-wallpaper.png".source = ../../assets/wallpapers/collection/Daytime-MNT.jpg;
      "cupcakes-os/cupcakes-os-logo.png".source = ../../assets/cupcakes-os-logo.png;
      "cupcakes-os/live-cosmic-background-all".text = ''
        (
            output: "all",
            source: Path("/run/current-system/sw/share/backgrounds/cupcakes-os/NightTime-MNT.png"),
            filter_by_theme: false,
            rotation_frequency: 3600,
            filter_method: Lanczos,
            scaling_mode: Zoom,
            sampling_method: Alphanumeric,
        )
      '';
      "cupcakes-os/live-cosmic-backgrounds".text = ''
        [All]
      '';
      "cupcakes-os/title.txt".source = ../../assets/cupcakes-os-title.txt;
      "cupcakes-os/VERSION".source = ../../VERSION;
      "cupcakes-os/fastfetch-logo.txt".source = ../../assets/fastfetch-logo.txt;
      "cupcakes-os/fastfetch-config.jsonc".source = ../../assets/fastfetch-config.jsonc;
      "cupcakes-os/effects/v3StartingCupcakes-OS.mp3".source = ../../assets/Effects/v3StartingCupcakes-OS.mp3;
      "cupcakes-os/desktop-profiles.sh" = {
        source = ../../scripts/cupcakes-os-desktop-profiles.sh;
        mode = "0755";
      };
      "cupcakes-os/mango/config.conf".source = ../../assets/mango/config.conf;
      "assets/mango/config.conf".source = ../../assets/mango/config.conf;
      "cupcakes-os/support-report.sh" = {
        source = ../../scripts/cupcakes-os-support-report.sh;
        mode = "0755";
      };
      "cupcakes-os/hardware-test.sh" = {
        source = ../../scripts/cupcakes-os-hardware-test.sh;
        mode = "0755";
      };
      "cupcakes-os/plymouth/cupcakes-os.plymouth".source = ../../assets/plymouth/cupcakes-os.plymouth;
      "cupcakes-os/plymouth/cupcakes-os.script".source = ../../assets/plymouth/cupcakes-os.script;
      "cupcakes-os/nixpkgs".source = pkgs.path;
      "xdg/fastfetch/config.jsonc".source = ../../assets/fastfetch-config.jsonc;
      "xdg/fastfetch/cupcakes-os-logo.txt".source = ../../assets/fastfetch-logo.txt;
      "issue".text = ''
        Cupcakes OS EVEREST 4.0
      '';
      "issue.net".text = ''
        Cupcakes OS EVEREST 4.0
      '';
      "profile.d/cupcakes-os-live.sh".text = ''
        # Only greet on real TTY sessions (not COSMIC/graphical login shells)
        case "$(tty 2>/dev/null)" in /dev/tty[0-9]*)
          if [ -z "$CUPCAKES_OS_LIVE_GREETED" ]; then
            export CUPCAKES_OS_LIVE_GREETED=1
            printf '\n'
            printf '\033[1;36m  ◈  CUPCAKES_OS OS \033[0;37m${version}\033[0m  —  Live Shell\033[0m\n'
            printf '\033[90m  ─────────────────────────────────────────────\033[0m\n'
            printf '\n'
            printf '  \033[1;37mcupcakes-os-install\033[0m        Start the installer\n'
            printf '  \033[90mcupcakes-os-install --force\033[0m  Force-restart installer\n'
            printf '\n'
            printf '  \033[90mType a command or press Ctrl+D to power off.\033[0m\n'
            printf '\n'
          fi
        esac
      '';
      "cupcakes-os/boot.sh" = {
        source = ../../scripts/cupcakes-os-boot.sh;
        mode = "0755";
      };
      "cupcakes-os/installer.sh" = {
        source = ../../scripts/cupcakes-os-installer.sh;
        mode = "0755";
      };
      "cupcakes-os/installer-gui.py" = {
        source = ../../scripts/cupcakes-os-installer-gui.py;
        mode = "0755";
      };
      "cupcakes-os/setup-launcher.sh" = {
        source = ../../scripts/cupcakes-os-setup-launcher.sh;
        mode = "0755";
      };
      "cupcakes-os/setup.desktop".source = ../../scripts/cupcakes-os-setup.desktop;
      "cupcakes-os/installed-base.nix".source = ../modules/installed-base.nix;
      "cupcakes-os/pkgs/mango.nix".source = ../pkgs/mango.nix;
      "cupcakes-os/pkgs/modularity.nix".source = ../pkgs/modularity.nix;
      "cupcakes-os/tinypm".source = tinypmDir;
      "cupcakes-os/docs".source = ../../docs;
      "cupcakes-os/cupcakes-os-options.nix".source  = ../modules/cupcakes-os-options.nix;
      "cupcakes-os/ui.sh" = {
        source = ../../scripts/cupcakes-os-ui.sh;
        mode   = "0644";
      };
      "cupcakes-os/config.sh" = {
        source = ../../scripts/cupcakes-os-config.sh;
        mode   = "0755";
      };
      "cupcakes-os/anix.sh" = {
        source = ../../scripts/anix.sh;
        mode = "0755";
      };
      "cupcakes-os/anix-module.nix".source = ../modules/anix.nix;
      "cupcakes-os/session-setup.sh" = {
        source = ../../scripts/cupcakes-os-session-setup.sh;
        mode = "0755";
      };
      "cupcakes-os/theme-sync.sh" = {
        source = ../../scripts/cupcakes-os-theme-sync.sh;
        mode = "0755";
      };
      "cupcakes-os/update.sh" = {
        source = ../../scripts/cupcakes-os-update.sh;
        mode = "0755";
      };
      "xdg/autostart/cupcakes-os-theme-sync.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Cupcakes OS Theme Sync
        Comment=Match GNOME accent colors to Cupcakes OS wallpapers
        Exec=cupcakes-os-theme-sync
        OnlyShowIn=GNOME;
        X-GNOME-Autostart-enabled=true
        NoDisplay=true
      '';
      "xdg/gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-application-prefer-dark-theme=0
        gtk-theme-name=Adwaita
        gtk-icon-theme-name=Adwaita
      '';
      "xdg/gtk-4.0/settings.ini".text = ''
        [Settings]
        gtk-application-prefer-dark-theme=0
        gtk-theme-name=Adwaita
        gtk-icon-theme-name=Adwaita
      '';
      "xdg/qt5ct/qt5ct.conf".text = ''
        [Appearance]
        color_scheme_path=/run/current-system/sw/share/qt5ct/colors/darker.conf
        custom_palette=true
        icon_theme=Adwaita
        standard_dialogs=default
        style=Fusion
      '';
      "xdg/qt6ct/qt6ct.conf".text = ''
        [Appearance]
        color_scheme_path=/run/current-system/sw/share/qt6ct/colors/darker.conf
        custom_palette=true
        icon_theme=Adwaita
        standard_dialogs=default
        style=Fusion
      '';
      "xdg/autostart/cupcakes-os-session-setup.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Cupcakes OS Session Setup
        Comment=Apply Cupcakes OS defaults for the current desktop session
        Exec=cupcakes-os-session-setup
        X-GNOME-Autostart-enabled=true
        NoDisplay=true
      '';
    }
    // builtins.listToAttrs (
      map
        (name: {
          name = "cupcakes-os/bootloader/${name}";
          value.source = ../../assets/bootloader + "/${name}";
        })
        (builtins.attrNames (builtins.readDir ../../assets/bootloader))
    )
    // builtins.listToAttrs (
      map
        (name: {
          name = "cupcakes-os/wallpapers/${name}";
          value.source = ../../assets/wallpapers/collection + "/${name}";
        })
        (builtins.attrNames (builtins.readDir ../../assets/wallpapers/collection))
    )
    // builtins.listToAttrs (
      map
        (name: {
          name = "cupcakes-os/themes/${name}";
          value.source = ../../assets/wallpaper-themes + "/${name}";
        })
        (builtins.attrNames (builtins.readDir ../../assets/wallpaper-themes))
    )
    // {
      "cupcakes-os/desktops".source = ../modules/desktops;
    };

  # ── Live user ─────────────────────────────────────────────────────────────────
  users.mutableUsers = false;
  users.users.liveuser = {
    isNormalUser = true;
    initialPassword = "";
    uid = 1000;
    extraGroups = [ "wheel" "video" "audio" "networkmanager" "input" "seat" ];
  };
  security.sudo.extraRules = [{
    users = [ "liveuser" ];
    commands = [{ command = "ALL"; options = [ "NOPASSWD" ]; }];
  }];

  # ── COSMIC live desktop ─────────────────────────────────────────────────────
  # Boot straight into the edition's graphical live session with an
  # "Install Cupcakes OS" launcher, similar to desktop-first distro installers.
  # The TUI installer is still available from a terminal with `cupcakes-os-install`.
  hardware.graphics.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "liveuser";
  };
  services.displayManager.defaultSession = selectedEdition.session;
  services.getty.autologinUser = "liveuser";

  services.xserver.enable = lib.mkDefault (selectedEdition.id != "cosmic");

  services.desktopManager.cosmic.enable = lib.mkIf (selectedEdition.id == "cosmic") true;

  services.desktopManager.gnome.enable = lib.mkIf (selectedEdition.id == "gnome") true;
  services.displayManager.gdm.enable = lib.mkIf (selectedEdition.id == "gnome") true;
  services.gnome.gnome-keyring.enable = lib.mkIf (selectedEdition.id == "gnome") true;

  services.desktopManager.plasma6.enable = lib.mkIf (selectedEdition.id == "kde") true;

  programs.hyprland = lib.mkIf (selectedEdition.id == "hyprland") {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services.displayManager.sessionPackages = lib.mkIf (selectedEdition.id == "other") [ pkgs.mango ];
  programs.xwayland.enable = lib.mkIf (selectedEdition.id == "other") true;

  services.displayManager.sddm = lib.mkIf (selectedEdition.id != "gnome") {
    enable = true;
    wayland.enable = true;
  };

  xdg.portal = lib.mkIf (selectedEdition.id == "hyprland" || selectedEdition.id == "other") {
    enable = true;
    extraPortals = if selectedEdition.id == "hyprland"
      then with pkgs; [ xdg-desktop-portal-hyprland xdg-desktop-portal-gtk ]
      else with pkgs; [ xdg-desktop-portal-wlr xdg-desktop-portal-gtk ];
    wlr.enable = selectedEdition.id == "other";
    config = if selectedEdition.id == "hyprland" then {
      hyprland.default = lib.mkForce [ "hyprland" "gtk" ];
      hyprland-uwsm.default = lib.mkForce [ "hyprland" "gtk" ];
      common.default = lib.mkForce [ "gtk" ];
    } else {
      mango.default = lib.mkForce [ "wlr" "gtk" ];
      common.default = lib.mkForce [ "gtk" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/liveuser/Desktop 0755 liveuser users -"
    "C /home/liveuser/Desktop/cupcakes-os-setup.desktop 0755 liveuser users - /etc/cupcakes-os/setup.desktop"
    "d /home/liveuser/.config 0755 liveuser users -"
    "d /home/liveuser/.config/cosmic 0755 liveuser users -"
    "d /home/liveuser/.config/cosmic/com.system76.CosmicBackground 0755 liveuser users -"
    "d /home/liveuser/.config/cosmic/com.system76.CosmicBackground/v1 0755 liveuser users -"
    "C /home/liveuser/.config/cosmic/com.system76.CosmicBackground/v1/all 0644 liveuser users - /etc/cupcakes-os/live-cosmic-background-all"
    "C /home/liveuser/.config/cosmic/com.system76.CosmicBackground/v1/backgrounds 0644 liveuser users - /etc/cupcakes-os/live-cosmic-backgrounds"
  ];

  systemd.services.ModemManager = {
    enable = lib.mkForce true;
    wantedBy = lib.mkForce [ "multi-user.target" ];
  };
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  virtualisation.vmware.guest.enable = pkgs.stdenv.hostPlatform.isx86;
  virtualisation.virtualbox.guest.enable = lib.mkForce false;
  virtualisation.hypervGuest.enable = lib.mkForce false;

  environment.shellAliases.fastfetch = "fastfetch -c /etc/xdg/fastfetch/config.jsonc";

  programs.bash.interactiveShellInit = ''
    [[ $SHLVL -eq 1 ]] && fastfetch -c /etc/xdg/fastfetch/config.jsonc
  '';

  systemd.services.NetworkManager = {
    enable = lib.mkForce true;
    wantedBy = lib.mkForce [ "multi-user.target" ];
  };
  systemd.services.cupcakes-os-unblock-radios = {
    description = "Unblock wireless and Bluetooth radios for the Cupcakes OS installer";
    wantedBy = [ "multi-user.target" ];
    before = [ "NetworkManager.service" "bluetooth.service" "wpa_supplicant.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.util-linux}/bin/rfkill unblock wifi || true
      ${pkgs.util-linux}/bin/rfkill unblock bluetooth || true
      ${pkgs.util-linux}/bin/rfkill unblock all || true
      ${pkgs.systemd}/bin/udevadm trigger --action=add --subsystem-match=net || true
      ${pkgs.systemd}/bin/udevadm trigger --action=add --subsystem-match=bluetooth || true
      ${pkgs.systemd}/bin/udevadm settle || true
    '';
  };
  systemd.services.cupcakes-os-wifi-ready = {
    description = "Ensure Wi-Fi is enabled and ready for NetworkManager on the live image";
    wantedBy = [ "multi-user.target" ];
    after = [
      "NetworkManager.service"
      "wpa_supplicant.service"
      "cupcakes-os-unblock-radios.service"
    ];
    wants = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.util-linux}/bin/rfkill unblock wifi || true
      ${pkgs.networkmanager}/bin/nmcli radio wifi on || true
      for _i in $(seq 1 30); do
        if ${pkgs.networkmanager}/bin/nmcli -t -f TYPE device status 2>/dev/null | grep -q '^wifi:'; then
          break
        fi
        sleep 1
      done
      ${pkgs.networkmanager}/bin/nmcli device wifi rescan || true
    '';
  };
  systemd.services.cupcakes-os-flatpak-setup = {
    description = "Add Flathub remote for Flatpak on the live image";
    after = [ "NetworkManager.service" "flatpak.service" ];
    wants = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for _i in $(seq 1 90); do
        if ${pkgs.curl}/bin/curl -fsI --connect-timeout 3 --max-time 8 \
          https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done
      ${pkgs.flatpak}/bin/flatpak remote-add --system --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo || true
      if id liveuser >/dev/null 2>&1; then
        ${pkgs.util-linux}/bin/runuser -u liveuser -- \
          ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub \
          https://dl.flathub.org/repo/flathub.flatpakrepo || true
      fi
    '';
  };
  systemd.services.cupcakes-os-boot = {
    description = "Cupcakes OS installer boot";
    wantedBy    = lib.mkForce [];
    wants       = [ "NetworkManager.service" ];
    # Conflict with both the static and auto-vt getty on tty1 so neither
    # can race with us for the terminal.
    conflicts = [ "getty@tty1.service" "autovt@tty1.service" ];
    # Start after network is up and sessions are ready.
    # plymouth-quit.service sends the quit signal to Plymouth;
    # we also call `plymouth quit` in ExecStartPre as a belt-and-suspenders.
    after = [
      "NetworkManager.service"
      "systemd-user-sessions.service"
      "plymouth-quit.service"
      "getty@tty1.service"
      "autovt@tty1.service"
    ];
    environment = {
      TERM                         = "linux";
      CUPCAKES_OS_VERSION                = version;
      CUPCAKES_OS_NIXPKGS_PATH           = "/etc/cupcakes-os/nixpkgs";
      CUPCAKES_OS_ZONEINFO_PATH          = "${pkgs.tzdata}/share/zoneinfo";
      CUPCAKES_OS_DESKTOP_PROFILES_LIB   = "/etc/cupcakes-os/desktop-profiles.sh";
      CUPCAKES_OS_APP_CATALOG_LIB        = "/etc/cupcakes-os/app-catalog.sh";
    };
    serviceConfig = {
      Type   = "simple";
      # Quit Plymouth before we take the TTY — avoids framebuffer race.
      # The leading '-' tells systemd to ignore a non-zero exit code.
      ExecStartPre  = "-${pkgs.plymouth}/bin/plymouth quit --wait";
      ExecStart     = "${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/boot.sh";
      # Never restart automatically. If the installer exits or crashes, the
      # boot script drops to a live shell; restarting this service can relaunch
      # the installer and feel like an install loop.
      Restart       = "no";
      RestartSec    = "2";
      StandardInput  = "tty-force";
      StandardOutput = "tty";
      StandardError  = "tty";
      TTYPath        = "/dev/tty1";
      TTYReset       = true;
      TTYVHangup     = true;
      # Do NOT set TTYVTDisallocate — it releases the VT on exit which breaks
      # the fallback live shell and makes restarts unable to re-acquire tty1.
    };
  };

  image.fileName = lib.mkForce "cupcakes-os-${version}-x86_64.iso";
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;
  isoImage.squashfsCompression = lib.mkForce "zstd -Xcompression-level 15";
  isoImage.prependToMenuLabel = "";
  isoImage.appendToMenuLabel = "";
  isoImage.showConfiguration = true;
  isoImage.splashImage = ../../assets/bootloader/background.png;
  isoImage.grubTheme = cupcakes-osGrubTheme;
  isoImage.syslinuxTheme = ''
    MENU RESOLUTION 800 600
    MENU CLEAR
    MENU WIDTH 46
    MENU MARGIN 0
    MENU ROWS 4
    MENU VSHIFT 8
    MENU HSHIFT 18
    MENU TABMSGROW 17
    MENU CMDLINEROW 18
    MENU TIMEOUTROW 19
    MENU HELPMSGROW 20
    MENU HELPMSGENDROW 20

    MENU COLOR BORDER       37;40      #00000000    #00000000   none
    MENU COLOR SCREEN       37;40      #00000000    #00000000   none
    MENU COLOR TABMSG       37;40      #D8E2F2      #00000000   none
    MENU COLOR TIMEOUT      1;37;40    #F3F6FB      #00000000   none
    MENU COLOR TIMEOUT_MSG  37;40      #D8E2F2      #00000000   none
    MENU COLOR CMDMARK      1;37;40    #F3F6FB      #00000000   none
    MENU COLOR CMDLINE      37;40      #D8E2F2      #00000000   none
    MENU COLOR TITLE        1;37;40    #00000000    #00000000   none
    MENU COLOR UNSEL        37;40      #D8E2F2      #00000000   none
    MENU COLOR SEL          1;30;47    #1B2539      #F3F6FB     std
  '';
}
