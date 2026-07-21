# Recovery

This page is the fast path when an Cupcakes OS install boots but something is wrong.

## First Checks

```sh
cupcakes-os doctor
anix status
anix doctor
anix --gui
tinypm system
```

## Roll Back

Use the normal Cupcakes OS rollback alias:

```sh
rollback
```

Or use ANIX directly:

```sh
anix generations
anix rollback nix
```

## Rebuild Current Profile

```sh
sudo nixos-rebuild switch --flake /etc/nixos#cupcakes-os
```

Or through ANIX:

```sh
anix switch nix cupcakes-os
```

## Repair Flake Purity

If rebuilds fail with `/nix/store/assets/mango/config.conf` in pure evaluation mode, repair the installed config first:

```sh
sudo cupcakes-os repair --mango
sudo nix --extra-experimental-features "nix-command flakes" flake update --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#cupcakes-os
```

Do not use `--impure` as the normal fix. The repair ensures `/etc/nixos/cupcakes-os/mango/config.conf` exists, rewrites copied Cupcakes OS modules away from repo-relative Mango asset paths, and runs `git add` when `/etc/nixos` is a Git flake tree.

## Test Before Switching

```sh
anix diff nix cupcakes-os
anix test nix cupcakes-os
```

## Boot Next Profile Without Switching Now

```sh
anix boot nix stable
```

Reboot when ready.

## Repair App Sources

```sh
tinypm repair
tinypm sources
```

If Flatpak is the issue:

```sh
cupcakes-os recovery
```

## Save A Snapshot

Before making larger changes:

```sh
anix save "before recovery changes"
```

## Support Report

```sh
cupcakes-os support-report
```

Attach the generated archive when asking for help.

## Live ISO Recovery

If the installed system does not boot:

1. Boot the Cupcakes OS ISO.
2. Choose the live shell.
3. Mount the installed root partition.
4. Inspect `/mnt/etc/nixos`.
5. Rebuild or copy out support logs.

The installer also detects an installed Cupcakes OS disk and warns when the ISO is still attached.
