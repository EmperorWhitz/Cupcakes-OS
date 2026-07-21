{ lib, pkgs, ... }:
let
  # All paths below are relative to this file as it lives on the installed system
  # (beside installed-base.nix in /etc/nixos/cupcakes-os/ or equivalent).  The
  # installer copies every required file via cp_required before the first
  # nixos-rebuild, so the ./x paths are always present.  Optional files that
  # the installer only copies when available fall back to null and their
  # environment.etc entries are guarded with lib.optionalAttrs.
  versionFile          = ./VERSION;
  titleFile            = ./title.txt;
  fastfetchLogoFile    = ./fastfetch-logo.txt;
  fastfetchConfigFile  = ./fastfetch-config.jsonc;
  uiScript             = ./ui.sh;
  configScript         = ./config.sh;
  cupcakes-osScript          = ./cupcakes-os.sh;
  desktopScript        = ./desktop.sh;
  doctorScript         = ./doctor.sh;
  checkFullScript      = ./check-full.sh;
  recoveryScript       = ./recovery.sh;
  welcomeScript        = ./welcome.sh;
  anixScript           = ./anix.sh;
  optionsModule        = ./cupcakes-os-options.nix;
  anixModule           = ./anix-module.nix;
  docsDir =
    if builtins.pathExists ./docs then ./docs else null;
  appCatalogScript     = ./app-catalog.sh;
  appManagerScript     = ./apps.sh;
  supportReportScript  = ./support-report.sh;
  hardwareTestScript   = ./hardware-test.sh;
  repairFlakePurityScript = ./repair-flake-purity.sh;
  wallpaperFile        = ./default-wallpaper.png;
  cupcakes-osLogoFile =
    if builtins.pathExists ./cupcakes-os-logo.png then ./cupcakes-os-logo.png else null;
  wallpaperDir         = ./wallpapers;
  wallpaperThemeDir    = ./themes;
  updateScript         = ./update.sh;
  themeSyncScript      = ./theme-sync.sh;
  sessionSetupScript   = ./session-setup.sh;
  desktopProfilesScript = ./desktop-profiles.sh;
  mangoConfigFile      = ./mango/config.conf;
  mangoConfigText      = builtins.readFile mangoConfigFile;
  installerScript      = ./installer.sh;
  setupLauncherScript  = ./setup-launcher.sh;
  setupDesktopFile     = ./setup.desktop;
  plymouthDir          = ./plymouth;
  bootloaderDir        = ./bootloader;
  effectsDir =
    if builtins.pathExists ./effects then ./effects else null;
  limineWallpaperFile =
    if builtins.pathExists (bootloaderDir + "/limine-background.png") then
      bootloaderDir + "/limine-background.png"
    else
      bootloaderDir + "/background.png";
  tinypmDir            = ./tinypm;
  version = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile versionFile);
  mkGrabCmd = name: pkgs.writeShellScriptBin name ''
    exec env TINYPM_FLAVOR=cupcakes-os ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/tinypm/${name} "$@"
  '';
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
  cupcakesOsRepairFlakePurity = pkgs.writeShellScriptBin "cupcakes-os-repair-flake-purity" ''
    exec env CUPCAKES_OS_SYSTEM_CONFIG=/etc/nixos ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/repair-flake-purity.sh "$@"
  '';
  cupcakesOsInstaller = pkgs.writeShellScriptBin "cupcakes-os-installer" ''
    exec env CUPCAKES_OS_INSTALLER=/etc/cupcakes-os/installer.sh \
      ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/installer.sh "$@"
  '';
  cupcakesOsSetup = pkgs.writeShellScriptBin "cupcakes-os-setup" ''
    exec env CUPCAKES_OS_INSTALLER=/etc/cupcakes-os/installer.sh \
      ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/setup-launcher.sh "$@"
  '';
  cupcakesOsSetupDesktopPkg = pkgs.runCommandLocal "cupcakes-os-setup-desktop" { } ''
    mkdir -p "$out/share/applications"
    cp ${setupDesktopFile} "$out/share/applications/cupcakes-os-setup.desktop"
  '';
  cupcakesOsUpdate = pkgs.writeShellScriptBin "cupcakes-os-update" ''
    exec env CUPCAKES_OS_UPDATE_COMMAND=cupcakes-os-update ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/update.sh "$@"
  '';
  cupcakesOsThemeSync = pkgs.writeShellScriptBin "cupcakes-os-theme-sync" ''
    exec env CUPCAKES_OS_GSETTINGS_BIN=${pkgs.glib}/bin/gsettings ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/theme-sync.sh "$@"
  '';
  cupcakesOsSessionSetup = pkgs.writeShellScriptBin "cupcakes-os-session-setup" ''
    exec env CUPCAKES_OS_GSETTINGS_BIN=${pkgs.glib}/bin/gsettings CUPCAKES_OS_THEME_SYNC_SCRIPT=/etc/cupcakes-os/theme-sync.sh ${pkgs.bashInteractive}/bin/bash /etc/cupcakes-os/session-setup.sh "$@"
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
  cupcakes-osPlymouthTheme = pkgs.runCommandLocal "cupcakes-os-plymouth-theme" { } ''
    install -Dm0644 ${plymouthDir + "/cupcakes-os.plymouth"} $out/share/plymouth/themes/cupcakes-os/cupcakes-os.plymouth
    install -Dm0644 ${plymouthDir + "/cupcakes-os.script"} $out/share/plymouth/themes/cupcakes-os/cupcakes-os.script
  '';
in
{
  system.nixos = {
    distroId = "cupcakes-os";
    distroName = "Cupcakes OS";
    vendorId = "cupcakes-os";
    vendorName = "Cupcakes OS";
    label = version;
    variant_id = lib.mkDefault "system";
    variantName = lib.mkDefault "Cupcakes OS EVEREST 4.0";
    extraOSReleaseArgs = lib.mapAttrs (_: lib.mkDefault) {
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

  nixpkgs.config.allowUnfree = lib.mkDefault true;

  nixpkgs.overlays = [
    (final: prev: {
      mango = final.callPackage ./pkgs/mango.nix {};
      modularity = final.callPackage ./pkgs/modularity.nix {};
    })
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.nixPath = [
    "nixpkgs=${pkgs.path}"
    "nixos-config=/etc/nixos/configuration.nix"
  ];

  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_6_6;
  boot.initrd.systemd.enable = lib.mkDefault true;
  boot.initrd.verbose = lib.mkDefault false;
  boot.kernelParams = lib.mkDefault [
    "quiet"
    "splash"
    "udev.log_level=3"
    "systemd.show_status=auto"
  ];
  boot.consoleLogLevel = lib.mkDefault 3;
  boot.initrd.availableKernelModules = lib.mkDefault [
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
  ];
  boot.kernelModules = lib.mkDefault [
    "btusb"
    "bluetooth"
  ];
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault false;
  boot.loader.limine.style.wallpapers = [ limineWallpaperFile ];
  boot.plymouth = {
    enable = lib.mkDefault true;
    theme = "cupcakes-os";
    themePackages = [ cupcakes-osPlymouthTheme ];
  };

  hardware.enableAllFirmware = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.bluetooth = {
    enable = lib.mkDefault true;
    powerOnBoot = lib.mkDefault true;
  };
  networking.networkmanager = {
    enable = lib.mkDefault true;
    wifi.powersave = lib.mkDefault false;
    ethernet.macAddress = lib.mkDefault "preserve";
    wifi.macAddress = lib.mkDefault "preserve";
  };
  services.dbus.packages = [ pkgs.wpa_supplicant ];
  networking.modemmanager.enable = lib.mkDefault true;
  security.polkit.enable = lib.mkDefault true;
  services.udisks2.enable = lib.mkDefault true;
  services.blueman.enable = lib.mkDefault true;
  services.fwupd.enable = lib.mkDefault true;
  services.openssh.enable = lib.mkDefault false;
  security.rtkit.enable = lib.mkDefault true;
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };

  services.flatpak.enable = lib.mkDefault true;
  xdg.portal.enable = lib.mkDefault true;
  xdg.portal.extraPortals = lib.mkDefault (with pkgs; [ xdg-desktop-portal-gtk ]);

  # Add Flathub automatically once the network is up.
  systemd.services.cupcakes-os-flatpak-setup = {
    description     = "Add Flathub remote for Flatpak";
    after           = [ "network-online.target" "flatpak.service" ];
    wants           = [ "network-online.target" ];
    wantedBy        = [ "multi-user.target" ];
    serviceConfig   = {
      Type            = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --system --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo || true
    '';
  };

  services.qemuGuest.enable = lib.mkDefault true;
  services.spice-vdagentd.enable = lib.mkDefault true;
  virtualisation.vmware.guest.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isx86;
  virtualisation.virtualbox.guest.enable = lib.mkDefault false;
  virtualisation.hypervGuest.enable = lib.mkDefault false;
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    inter
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];
  fonts.fontconfig = {
    enable = lib.mkDefault true;
    defaultFonts = {
      sansSerif = lib.mkDefault [ "Inter" "Noto Sans" ];
      serif     = lib.mkDefault [ "Noto Serif" ];
      monospace = lib.mkDefault [ "JetBrains Mono" "Noto Sans Mono" ];
      emoji     = lib.mkDefault [ "Noto Color Emoji" ];
    };
  };

  environment.variables = {
    XCURSOR_THEME = lib.mkDefault "Adwaita";
    XCURSOR_SIZE  = lib.mkDefault "24";
    TERMINAL      = lib.mkDefault "konsole";
    TERM_PROGRAM  = lib.mkDefault "konsole";
  };

  environment.systemPackages = with pkgs; [
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
    anixCommand
    cupcakesOsConfig
    cupcakesOsDesktop
    cupcakesOsDoctor
    cupcakesOsHardwareTest
    cupcakesOsRecovery
    cupcakesOsRepairFlakePurity
    cupcakesOsSupportReport
    cupcakesOsUpdate
    cupcakesOsWelcome
    cupcakes-osWallpapersPackage
    cupcakesOsInstaller
    cupcakesOsSetup
    cupcakesOsSetupDesktopPkg
    cupcakesOsSessionSetup
    cupcakesOsThemeSync
    bashInteractive
    curl
    dmidecode
    ethtool
    feh
    fastfetch
    gh
    git
    htop
    iw
    kdePackages.konsole
    linux-firmware
    modemmanager
    nixosCommand
    pciutils
    mpg123
    smartmontools
    updateCommand
    upgradeCommand
    rollbackCommand
    spaceship-prompt
    starship
    usbutils
    wget
    wpa_supplicant
    papirus-icon-theme
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    xdg-utils
    xterm
    zenity
    swaybg
    zsh
  ];

  programs.zsh = {
    enable = true;
    shellInit = ''
      if [[ -o interactive ]]; then
        cupcakes_os_zdotdir="''${ZDOTDIR:-''${HOME:-}}"
        if [[ -n "$cupcakes_os_zdotdir" && -d "$cupcakes_os_zdotdir" && -w "$cupcakes_os_zdotdir" \
          && ! -e "$cupcakes_os_zdotdir/.zshenv" \
          && ! -e "$cupcakes_os_zdotdir/.zprofile" \
          && ! -e "$cupcakes_os_zdotdir/.zshrc" \
          && ! -e "$cupcakes_os_zdotdir/.zlogin" ]]; then
          {
            print -r -- "# Cupcakes OS zsh profile."
            print -r -- "# System-wide prompt and fastfetch setup live in /etc/zshrc."
          } > "$cupcakes_os_zdotdir/.zshrc" 2>/dev/null || true
        fi
        unset cupcakes_os_zdotdir
      fi
    '';
    interactiveShellInit = ''
      export FASTFETCH_CONFIG="/etc/xdg/fastfetch/config.jsonc"
      export CUPCAKES_OS_FASTFETCH_LOGO="/etc/xdg/fastfetch/cupcakes-os-logo.txt"

      if [[ -o interactive && -z "''${CUPCAKES_OS_FASTFETCH_SHOWN:-}" && "''${SHLVL:-1}" -eq 1 ]]; then
        export CUPCAKES_OS_FASTFETCH_SHOWN=1
        command fastfetch --logo-type file --logo-source "$CUPCAKES_OS_FASTFETCH_LOGO" -c "$FASTFETCH_CONFIG" 2>/dev/null || true
        print
      fi
    '';
    promptInit = ''
      fpath=(${pkgs.spaceship-prompt}/share/zsh/site-functions $fpath)
      autoload -Uz promptinit
      promptinit

      SPACESHIP_PROMPT_ORDER=(
        user host dir git package node python rust golang docker nix_shell
        exec_time line_sep jobs exit_code char
      )
      SPACESHIP_USER_SHOW=always
      SPACESHIP_HOST_SHOW=always
      SPACESHIP_DIR_TRUNC=3
      SPACESHIP_PROMPT_ADD_NEWLINE=true
      SPACESHIP_CHAR_SYMBOL="➜"
      SPACESHIP_CHAR_SUFFIX=" "
      prompt spaceship
    '';
  };

  users.defaultUserShell = pkgs.zsh;

  environment.etc =
    {
      "cupcakes-os/VERSION".source = versionFile;
      "cupcakes-os/ui.sh" = {
        source = uiScript;
        mode = "0644";
      };
      "cupcakes-os/config.sh" = {
        source = configScript;
        mode = "0755";
      };
      "cupcakes-os/cupcakes-os.sh" = {
        source = cupcakes-osScript;
        mode = "0755";
      };
      "cupcakes-os/desktop.sh" = {
        source = desktopScript;
        mode = "0755";
      };
      "cupcakes-os/doctor.sh" = {
        source = doctorScript;
        mode = "0755";
      };
      "cupcakes-os/check-full.sh" = {
        source = checkFullScript;
        mode = "0755";
      };
      "cupcakes-os/recovery.sh" = {
        source = recoveryScript;
        mode = "0755";
      };
      "cupcakes-os/welcome.sh" = {
        source = welcomeScript;
        mode = "0755";
      };
      "cupcakes-os/anix.sh" = {
        source = anixScript;
        mode = "0755";
      };
      "cupcakes-os/app-catalog.sh" = {
        source = appCatalogScript;
        mode = "0755";
      };
      "cupcakes-os/apps.sh" = {
        source = appManagerScript;
        mode = "0755";
      };
      "cupcakes-os/support-report.sh" = {
        source = supportReportScript;
        mode = "0755";
      };
      "cupcakes-os/hardware-test.sh" = {
        source = hardwareTestScript;
        mode = "0755";
      };
      "cupcakes-os/repair-flake-purity.sh" = {
        source = repairFlakePurityScript;
        mode = "0755";
      };
      "cupcakes-os/default-wallpaper.png".source = wallpaperFile;
      "cupcakes-os/title.txt".source = titleFile;
      "cupcakes-os/fastfetch-logo.txt".source = fastfetchLogoFile;
      "cupcakes-os/fastfetch-config.jsonc".source = fastfetchConfigFile;
      "cupcakes-os/desktop-profiles.sh" = {
        source = desktopProfilesScript;
        mode = "0755";
      };
      "cupcakes-os/mango/config.conf".source = mangoConfigFile;
      "mango/config.conf".text = lib.mkDefault mangoConfigText;
      "cupcakes-os/tinypm".source = tinypmDir;
      # The generated /etc/nixos/flake.nix pins its nixpkgs input to
      # "path:/etc/cupcakes-os/nixpkgs". Expose the build-time nixpkgs source here so
      # that path resolves on the installed system (the live ISO does the same).
      # Without this, `anix apply` / nixos-rebuild fail to fetch the flake input.
      "cupcakes-os/nixpkgs".source = pkgs.path;
      "cupcakes-os/installer.sh" = {
        source = installerScript;
        mode = "0755";
      };
      "cupcakes-os/setup-launcher.sh" = {
        source = setupLauncherScript;
        mode = "0755";
      };
      "cupcakes-os/setup.desktop".source = setupDesktopFile;
      "cupcakes-os/session-setup.sh" = {
        source = sessionSetupScript;
        mode = "0755";
      };
      "cupcakes-os/update.sh" = {
        source = updateScript;
        mode = "0755";
      };
      "cupcakes-os/theme-sync.sh" = {
        source = themeSyncScript;
        mode = "0755";
      };
      "motd".text = ''
        Cupcakes OS EVEREST ${version}

          grab <app>          install an app  (flatpak, nix, or snap)
          search <app>        find apps across all sources
          term <app>          remove an installed app
          supdate             upgrade all installed apps

          cupcakes-os welcome       first steps and quick actions
          cupcakes-os doctor        check system health
          cupcakes-os recovery      rollback and repair tools
          sudo nixos update   rebuild and switch the system
      '';
      "profile.d/cupcakes-os-welcome.sh".text = ''
        if [ -n "''${PS1:-}" ] && [ -z "''${CUPCAKES_OS_WELCOME_SHOWN:-}" ] && command -v cupcakes-os-welcome >/dev/null 2>&1; then
          export CUPCAKES_OS_WELCOME_SHOWN=1
          if [ ! -f "$HOME/.cache/cupcakes-os/welcome-seen" ]; then
            mkdir -p "$HOME/.cache/cupcakes-os"
            touch "$HOME/.cache/cupcakes-os/welcome-seen"
            cupcakes-os-welcome status || true
            printf '  Run %s for first-step actions.\n\n' "cupcakes-os welcome"
          fi
        fi
      '';
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
        gtk-application-prefer-dark-theme=1
        gtk-theme-name=Adwaita-dark
        gtk-icon-theme-name=Papirus-Dark
      '';
      "xdg/gtk-4.0/settings.ini".text = ''
        [Settings]
        gtk-application-prefer-dark-theme=1
        gtk-theme-name=Adwaita-dark
        gtk-icon-theme-name=Papirus-Dark
      '';
      "xdg/qt5ct/qt5ct.conf".text = ''
        [Appearance]
        color_scheme_path=/run/current-system/sw/share/qt5ct/colors/darker.conf
        custom_palette=true
        icon_theme=Papirus-Dark
        standard_dialogs=default
        style=Fusion
      '';
      "xdg/qt6ct/qt6ct.conf".text = ''
        [Appearance]
        color_scheme_path=/run/current-system/sw/share/qt6ct/colors/darker.conf
        custom_palette=true
        icon_theme=Papirus-Dark
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
      "cupcakes-os/plymouth/cupcakes-os.plymouth".source = plymouthDir + "/cupcakes-os.plymouth";
      "cupcakes-os/plymouth/cupcakes-os.script".source = plymouthDir + "/cupcakes-os.script";
      "xdg/fastfetch/config.jsonc".source = fastfetchConfigFile;
      "xdg/fastfetch/cupcakes-os-logo.txt".source = fastfetchLogoFile;
      "skel/.config/fastfetch/config.jsonc".source = fastfetchConfigFile;
      "skel/.config/fastfetch/cupcakes-os-logo.txt".source = fastfetchLogoFile;
      "skel/.zshrc".text = ''
        # Cupcakes OS terminal profile. System-wide setup lives in /etc/zshrc.
      '';
      "skel/.config/konsolerc".text = ''
        [Desktop Entry]
        DefaultProfile=Cupcakes-OS.profile

        [KonsoleWindow]
        RememberWindowSize=false
      '';
      "skel/.local/share/konsole/Cupcakes-OS.profile".text = ''
        [Appearance]
        ColorScheme=Cupcakes OS
        Font=JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0

        [General]
        Command=${pkgs.zsh}/bin/zsh
        Name=Cupcakes OS
        Parent=FALLBACK/

        [Scrolling]
        HistoryMode=2
      '';
      "skel/.local/share/konsole/Cupcakes-OS.colorscheme".text = ''
        [Background]
        Color=5,10,18

        [BackgroundIntense]
        Color=8,18,30

        [Color0]
        Color=8,13,22

        [Color1]
        Color=255,90,113

        [Color2]
        Color=88,214,141

        [Color3]
        Color=255,214,102

        [Color4]
        Color=71,168,255

        [Color5]
        Color=181,137,255

        [Color6]
        Color=78,226,232

        [Color7]
        Color=226,238,248

        [Foreground]
        Color=232,244,255

        [ForegroundIntense]
        Color=255,255,255

        [General]
        Blur=true
        ColorRandomization=false
        Description=Cupcakes OS
        Opacity=0.84
      '';
      "issue".text = ''
        Cupcakes OS EVEREST 4.0
      '';
      "issue.net".text = ''
        Cupcakes OS EVEREST 4.0
      '';
    }
    // builtins.listToAttrs (
      map (name: {
        name = "cupcakes-os/bootloader/${name}";
        value.source = bootloaderDir + "/${name}";
      }) (builtins.attrNames (builtins.readDir bootloaderDir))
    )
    // builtins.listToAttrs (
      map (name: {
        name = "cupcakes-os/wallpapers/${name}";
        value.source = wallpaperDir + "/${name}";
      }) (builtins.attrNames (builtins.readDir wallpaperDir))
    )
    // builtins.listToAttrs (
      map (name: {
        name = "cupcakes-os/themes/${name}";
        value.source = wallpaperThemeDir + "/${name}";
      }) (builtins.attrNames (builtins.readDir wallpaperThemeDir))
    )
    // {
      "cupcakes-os/desktops".source = ./desktops;
    }
    // {
      "cupcakes-os/cupcakes-os-options.nix".source = optionsModule;
    }
    // {
      "cupcakes-os/anix-module.nix".source = anixModule;
    }
    // lib.optionalAttrs (docsDir != null) {
      "cupcakes-os/docs".source = docsDir;
    }
    // lib.optionalAttrs (cupcakes-osLogoFile != null) {
      "cupcakes-os/cupcakes-os-logo.png".source = cupcakes-osLogoFile;
    }
    // lib.optionalAttrs (effectsDir != null) {
      "cupcakes-os/effects/v3StartingCupcakes-OS.mp3".source = effectsDir + "/v3StartingCupcakes-OS.mp3";
    };

  environment.shellAliases.fastfetch = "fastfetch -c /etc/xdg/fastfetch/config.jsonc";

  programs.bash.interactiveShellInit = ''
    [[ $SHLVL -eq 1 ]] && fastfetch -c /etc/xdg/fastfetch/config.jsonc
  '';
}
