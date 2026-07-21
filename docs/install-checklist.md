# Cupcakes OS Install Checklist

Use this after building a release candidate ISO and after running one real install.

## Live Session

- ISO reaches the live boot flow without dropping to an emergency shell
- live boot flow opens on `tty1`
- NetworkManager starts before the installer network step
- installer opens without dropping into a shell first
- Omarchy-inspired welcome screen appears before disk/account questions
- networking works in the live session
- `/etc/cupcakes-os/setup.desktop` exists
- `/etc/cupcakes-os/setup-launcher.sh` exists and is executable
- `/etc/cupcakes-os/default-wallpaper.png` exists
- `/etc/cupcakes-os/wallpapers/` contains the curated wallpaper set
- Fastfetch shows the Cupcakes OS logo

## VM Coverage

- QEMU fresh install works end to end with `make qemu-fresh`
- installed disk boots with `make qemu-disk`
- at least one Windows-host VM run is checked in VMware or Hyper-V when possible
- if testing Hyper-V Generation 2, secure boot is disabled
- if testing VirtualBox, boot is checked with default graphics settings first

## Installer

- network step can open `nmtui`
- disk selection and user creation remain interactive
- password mismatch recovery works
- GitHub login can be skipped cleanly
- generated config validation runs before `nixos-install`
- install progress reaches the install phase
- install completes without fatal errors
- failed installs show useful recent log output
- `/tmp/cupcakes-os-install.log` and `/tmp/cupcakes-os-config.log` are present on failure

## Installed System

- installed system boots without the ISO attached
- bootloader starts without manual repair
- login prompt starts
- networking is enabled and functional
- `cupcakes-os setup` launches the installed reconfiguration tool
- `grab`, `search`, `term`, `start`, and `supdate` are available
- on GNOME installs, Cupcakes OS wallpapers appear in `Settings -> Appearance`
- on every supported desktop, first login starts on the Cupcakes OS default wallpaper
- on GNOME installs, picking an Cupcakes OS wallpaper updates accent/style automatically

## Bug Report

Collect:

```sh
journalctl -b --no-pager
```

and attach installer logs if available.
