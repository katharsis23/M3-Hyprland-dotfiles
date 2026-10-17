# Material Hyprland Starter

Starter scaffold for a Material 3-inspired Quickshell + Hyprland desktop on Linux Mint with Nix.

## Contents

- `dependencies.json`: declarative APT and Nix dependency manifest.
- `scripts/install.sh`: installer with dry-run, optional package handling, backups, and opt-out flags.
- `scripts/doctor.sh`: basic dependency/session diagnostics.
- `shell/shell.qml`: intentionally minimal Quickshell panel to validate startup.
- `config/hypr/material-hyprland.conf`: a fragment sourced by your existing Hyprland config.
- `config/defaults/apps.json`: default application fallback preferences.

## Prerequisites

- Linux Mint (tested design target: Mint 22.x), Bash, Python 3, sudo.
- Nix installed and working for Nix-managed packages.
- Existing Cinnamon session retained as a recovery path.

## Install

First inspect planned actions:

```bash
./scripts/install.sh --dry-run
```

Then install:

```bash
./scripts/install.sh
```

To skip one package manager:

```bash
./scripts/install.sh --skip-apt
./scripts/install.sh --skip-nix
```

Run diagnostics:

```bash
./scripts/doctor.sh
```

## Important notes

- The manifest is JSON so the installer can parse it with Python's standard library; no `jq` dependency is needed to parse the manifest.
- Nix package availability can vary by nixpkgs revision. The installer reports failed Nix installs and continues.
- APT required packages are installed as a group. If a required package is unavailable, APT may stop that group; check the output and adjust `dependencies.json`.
- Optional APT/Nix packages are attempted individually.
- The installer backs up existing `~/.config/hypr/hyprland.conf` before appending the source line, and backs up an existing managed fragment before replacing it.
- It does not edit SDDM, create a Wayland session file, or remove Cinnamon. Session registration should be a separate, verified step after the Hyprland executable and shell work.
- The starter QML is a smoke-test panel, not the finished full Material 3 shell. Add features as modules after confirming `qs -c material-hyprland` works.
- Quickshell package builds should bring their compatible Qt runtime. Avoid installing arbitrary Qt runtime libraries from a different package source.

## Package manager policy (manifest schema v2)

`dependencies.json` assigns each package one preferred manager (`apt` or `nix`).
The installer does not intentionally install the same dependency through both managers.
Fallback is opt-in:

```bash
./scripts/install.sh --dry-run
./scripts/install.sh
./scripts/install.sh --allow-fallback
```

The fallback flag tries the alternate manager only when the preferred install fails and
the manifest defines a corresponding package name/attribute. This can still result in a
package being installed from the fallback source, so review the output before using it.
