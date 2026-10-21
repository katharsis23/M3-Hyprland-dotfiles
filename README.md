# Material Hyprland Starter

Starter scaffold for a Material 3-inspired Quickshell + Hyprland desktop on Linux Mint with Nix.
Inspired by [End4 config](https://github.com/end-4/dots-hyprland.git)

## Contents

- `dependencies.json`: declarative APT and Nix dependency manifest.
- `scripts/install.sh`: installer with dry-run, optional package handling, backups, and opt-out flags.
- `scripts/doctor.sh`: basic dependency/session diagnostics.
- `scripts/apply-theme.sh`: regenerate the terminal palette from a wallpaper with matugen.
- `theme/`: matugen config (`theme/matugen/config.toml`) and templates (`theme/templates/`).
- `kitty/kitty.conf`: kitty config with a Nerd Font and a matugen include.
- `fish/config.fish`: fish config that sources the generated colours.
- `starship/starship.toml`: prompt config (a generated copy overrides it at runtime).
- `shell/shell.qml`: Quickshell panel.
- `config/defaults/apps.json`: default application fallback preferences.

## Shell features (Quickshell)

- **In-shell launcher** (`shell/qt/windows/Launcher.qml`) on `SUPER+SPACE`; fuzzel
  stays available as a fallback.
- **Wallpaper picker** (`shell/qt/windows/WallpaperPicker.qml`) on
  `SUPER+CTRL+T` — a thumbnail grid backed by `core/WallpaperService.qml` and
  `shell/qt/scripts/wallpaper-scan.sh`. Settings → Appearance → **Blur
  wallpaper** softly blurs the background (via ImageMagick) while the palette
  is still sampled from the sharp image; the choice persists in
  `~/.cache/material-hyprland/wallpaper-blur`.
- **AI assistant drawer** (`shell/qt/windows/AiSidebar.qml`) on `SUPER+ALT+L`.
- **System sidebar** on `SUPER+D`, **quick settings** on `SUPER+N`,
  **calendar** on `SUPER+COMMA`, **shortcuts** on `SUPER+SLASH`,
  **settings** on `SUPER+S`.

## Dynamic theme (all apps)

The whole desktop is recoloured from the active wallpaper with
[matugen](https://github.com/InioX/matugen) (Material 3). Flipping the
dark/light switch in Settings (or Quick Settings) regenerates every consumer —
kitty, fish, starship **and** GTK apps (Nemo, dialogs) — and flips the GTK
`color-scheme`, so terminal and file manager match the shell:

- `kitty/kitty.conf` includes the generated `~/.local/state/theme/generated/kitty.conf`.
- `fish/config.fish` sources `~/.local/state/theme/generated/fish-colors.fish`.
- `theme/templates/gtk-3.0.css` / `gtk-4.0.css` write `~/.config/gtk-3.0/gtk.css`
  and `~/.config/gtk-4.0/gtk.css`.
- The chosen mode is persisted in `~/.local/state/theme/mode` and reused when a
  new wallpaper is applied (`hypr/scripts/wallpaper_manager.py`).

