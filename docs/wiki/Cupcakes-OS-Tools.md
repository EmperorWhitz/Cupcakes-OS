# Cupcakes OS Tools

Cupcakes OS includes a small command layer for distro-specific tasks.

Use these commands for Cupcakes OS health, setup, recovery, desktop selection, updates, support reports, and system configuration.

## Main Commands

| Command | Purpose |
|---|---|
| `cupcakes-os welcome` | Show first-step status and useful actions |
| `cupcakes-os doctor` | Check install health, Flatpak, themes, boot assets, updates, and ANIX |
| `cupcakes-os recovery` | Rollback, rebuild, repair, and support actions |
| `cupcakes-os setup` | Installed reconfiguration launcher |
| `cupcakes-os config` | View or change installed Cupcakes OS settings |
| `cupcakes-os desktop list` | List supported desktop profiles |
| `cupcakes-os desktop set <profile>` | Change desktop profile |
| `cupcakes-os apps` | App bundle and catalog helpers |
| `cupcakes-os support-report` | Collect support diagnostics |
| `cupcakes-os update` | Cupcakes OS update helper used by `sudo nixos update` |

## Normal Installed Workflow

```sh
cupcakes-os doctor
anix status
anix --gui
tinypm sources
sudo nixos update
```

## Configuration

Show current config:

```sh
cupcakes-os config
```

Change common values:

```sh
cupcakes-os config set hostname my-pc
cupcakes-os config set timezone America/New_York
cupcakes-os config set desktop gnome
cupcakes-os config apply
```

For ANIX-managed values:

```sh
anix set hostname my-pc
anix set desktop hyprland
anix apply
```

## Desktop Profiles

List profiles:

```sh
cupcakes-os desktop list
```

Switch profile:

```sh
cupcakes-os desktop set plasma
```

Then rebuild or apply through the relevant Cupcakes OS/ANIX flow.

## App Layer

Use TinyPM for apps:

```sh
grab firefox
tinypm search krita
tinypm sources
```

Use ANIX or Cupcakes OS config for system-level changes.

## Support

Collect a report:

```sh
cupcakes-os support-report
```

Run health checks:

```sh
cupcakes-os doctor
anix doctor
tinypm doctor
```
