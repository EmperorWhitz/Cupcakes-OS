# Updating Cupcakes OS

Cupcakes OS uses a flake-based update flow for installed systems.

## Normal Update

On an installed Cupcakes OS system, run:

```sh
sudo nixos update
```

These aliases run the same updater:

```sh
update
upgrade
cupcakes-os-update
```

## What The Updater Does

The update helper:

- resolves the selected Cupcakes OS channel
- fetches the latest Cupcakes OS project files into `/etc/nixos/.cupcakes-os-upstream`
- syncs the installed Cupcakes OS files under `/etc/nixos/cupcakes-os/`
- optionally offers a local ANIX snapshot before rebuilding
- updates the flake inputs
- runs `nixos-rebuild switch`

## Channels

Show the current channel:

```sh
nixos channel
```

List channels:

```sh
nixos channel list
```

Switch channels:

```sh
sudo nixos channel set stable
sudo nixos channel set unstable
```

- `stable` tracks the latest tagged Cupcakes OS release
- `unstable` tracks the `main` branch

## Safer Update Habit

Before a larger update:

```sh
anix save "before update"
anix status
sudo nixos update
```

## Rollback

If the update is not good:

```sh
sudo nixos rollback
```

Or with ANIX:

```sh
anix generations
anix rollback nix
```

## Related Tools

- `cupcakes-os doctor`: check system health
- `cupcakes-os recovery`: rollback, rebuild, repair, and support actions
- `cupcakes-os setup`: installed reconfiguration launcher
- `anix status`: show profile, generation, and snapshot state
- `anix save`: local `/etc/nixos` snapshot
- `anix diff nix <profile>`: preview profile changes
- `anix test nix <profile>`: test-activate a profile
- `tinypm sources`: show app/package source status

## Notes

- This is for installed Cupcakes OS systems.
- It does not use classic manual NixOS channel updates.
- If the updater fails while fetching files, check the reported git error first.
