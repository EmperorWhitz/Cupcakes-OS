{ lib, pkgs, config, ... }:
# ── Cupcakes OS options module ───────────────────────────────────────────────────
# Provides the cupcakes-os.* option namespace so cupcakes-os-local.nix can be written
# as simple key-value pairs rather than raw NixOS expressions.
#
# This module is safe to import on older installs: it does nothing unless
# cupcakes-os.user.name is set.
let
  cfg = config.cupcakesOs;
  active = cfg.user.name != null;
  wallpaperDir = ./wallpapers;
  bundledWallpaperNames = [
    "Daytime-MNT.jpg"
    "NightTime-MNT.png"
    "oceandusk.png"
    "bluehorizon.png"
    "astronautwallpaper.png"
    "glacierreflection.png"
  ];
  discoveredWallpaperNames =
    builtins.attrNames (builtins.readDir wallpaperDir);
  wallpaperNames =
    lib.unique (bundledWallpaperNames ++ discoveredWallpaperNames);
  defaultWallpaperPath = "/run/current-system/sw/share/backgrounds/cupcakes-os/${cfg.wallpaper}";

  desktopLabel = {
    none         = "No desktop";
    gnome        = "GNOME";
    plasma       = "Plasma";
    hyprland     = "Hyprland";
    sway         = "Sway";
    xfce         = "XFCE";
    cinnamon     = "Cinnamon";
    mate         = "MATE";
    budgie       = "Budgie";
    lxqt         = "LXQt";
    pantheon     = "Pantheon";
    i3           = "i3";
    awesome      = "AwesomeWM";
    openbox      = "Openbox";
    niri         = "Niri";
    river        = "River";
    qtile        = "Qtile";
    bspwm        = "BSPWM";
    fluxbox      = "Fluxbox";
    icewm        = "IceWM";
    herbstluftwm = "Herbstluftwm";
    cosmic       = "COSMIC";
    mangowm      = "MangoWM";
  }.${cfg.desktop} or "Cupcakes OS";

in
{
  imports = import ./desktops/default.nix;

  options.cupcakesOs = {
    # ── Identity ────────────────────────────────────────────────────────────

    hostname = lib.mkOption {
      type    = lib.types.str;
      default = "cupcakes-os";
      description = "The machine hostname.";
    };

    locale = lib.mkOption {
      type    = lib.types.str;
      default = "en_US.UTF-8";
      example = "de_DE.UTF-8";
      description = "System locale (e.g. en_US.UTF-8, de_DE.UTF-8, fr_FR.UTF-8).";
    };

    timezone = lib.mkOption {
      type    = lib.types.str;
      default = "UTC";
      example = "America/New_York";
      description = "System timezone (see /usr/share/zoneinfo for valid values).";
    };

    keyboard = {
      console = lib.mkOption {
        type    = lib.types.str;
        default = "us";
        description = "Console keymap used in TTYs (e.g. us, de, fr).";
      };
      xkb = lib.mkOption {
        type    = lib.types.str;
        default = "us";
        description = "X11/Wayland keyboard layout (e.g. us, de, fr).";
      };
    };

    # ── User ────────────────────────────────────────────────────────────────

    user = {
      name = lib.mkOption {
        type    = lib.types.nullOr lib.types.str;
        default = null;
        description = "Primary user account name. Setting this activates the full Cupcakes OS config.";
      };
      hashedPassword = lib.mkOption {
        type    = lib.types.str;
        default = "";
        description = "Hashed password for the primary user. Generate with: mkpasswd";
      };
    };

    # ── Desktop ─────────────────────────────────────────────────────────────

    desktop = lib.mkOption {
      type = lib.types.enum [
        "none" "gnome" "plasma" "hyprland" "sway" "xfce" "cinnamon" "mate"
        "budgie" "lxqt" "pantheon" "i3"
        "awesome" "openbox" "niri" "river" "qtile" "bspwm" "fluxbox"
        "icewm" "herbstluftwm" "cosmic" "mangowm"
      ];
      default     = "cosmic";
      description = "Desktop environment or window manager to enable.";
    };

    # ── Hardware ────────────────────────────────────────────────────────────

    disk = lib.mkOption {
      type    = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/sda";
      description = "Install disk for the Limine bootloader (e.g. /dev/sda, /dev/nvme0n1).";
    };

    stateVersion = lib.mkOption {
      type    = lib.types.str;
      default = "26.05";
      description = "NixOS state version. Set once at install time — do not change afterwards.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.enum wallpaperNames;
      default = "Daytime-MNT.jpg";
      description = "Default wallpaper file shipped with Cupcakes OS.";
    };
  };

  # ── Config ─────────────────────────────────────────────────────────────────
  # Nothing below applies unless cupcakes-os.user.name is set.

  config = lib.mkMerge [

    # Always apply these with mkDefault so they lose to any direct override.
      {
        networking.hostName  = lib.mkDefault cfg.hostname;
        time.timeZone        = lib.mkDefault cfg.timezone;
        i18n.defaultLocale   = lib.mkDefault cfg.locale;
        console.keyMap       = lib.mkDefault cfg.keyboard.console;
        environment.variables.CUPCAKES_OS_DEFAULT_WALLPAPER = lib.mkDefault defaultWallpaperPath;
      }

    # Everything else requires cupcakes-os.user.name to be set.
    (lib.mkIf active (lib.mkMerge [

      # ── Common ─────────────────────────────────────────────────────────
      {
        # OS release args (PRETTY_NAME etc.) live in installed-base.nix only.

        system.nixos.variantName = lib.mkOverride 900 "Cupcakes OS ${desktopLabel} Edition";
        system.nixos.variant_id  = lib.mkOverride 900 cfg.desktop;

        system.stateVersion = cfg.stateVersion;

        security.sudo.wheelNeedsPassword = true;

        users.users.${cfg.user.name} = {
          isNormalUser = true;
          description  = "Cupcakes OS User";
          createHome   = true;
          shell        = pkgs.zsh;
          extraGroups  = [ "wheel" "networkmanager" "audio" "video" ];
          hashedPassword = cfg.user.hashedPassword;
        };
      }

      # ── Bootloader ─────────────────────────────────────────────────────
      (lib.mkIf (cfg.disk != null) {
        boot.loader.grub.enable = lib.mkForce false;
        boot.loader.timeout = lib.mkDefault 5;
        boot.loader.limine = {
          enable              = true;
          enableEditor        = false;
          maxGenerations      = lib.mkDefault 8;
          biosSupport         = true;
          biosDevice          = cfg.disk;
          efiSupport          = true;
          efiInstallAsRemovable = true;
        };
      })

    ])) # end mkIf active
  ];
}
