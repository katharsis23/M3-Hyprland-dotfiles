# TODO list

## Rules
Statuses:
    1. *TODO*: - Backlog
    2. *IN PROGRESS* - Currently on job
    3. *IN REVIEW* - Not tested fully
    4. *Completed* - Finished the task. Also wrap the task with

## Tasks
1. Add python3 declaratively in dependencies as well as starship, fonts, eza <Completed>
2. Update installation script to add fish starship and kitty config <Completed>
3. Add JetBrainsNerd fonts to quickshell as default and offer to commit in settings <In Review>
4. Add kitty icon in App Bar workspace <Completed>
5. Launch Quickshell on start of Hyprland <Completed>
6. Fix SPACE+RETURN shortcut of kitty to "kitty -e fish" <Completed>
7. Create separated widget for Wallpaper picker on Shortcut SUPER+CTRL+T. <Completed>
8. Light Theme should be applied to All applications(File Manager, Terminal etc) <In Review>
9. Set App Launcher on SUPER shortcut <Completed>
10. Add shortcuts on AI sidebar on SUPER+ALT+L <Completed>
11. Fix Adaptivity on TopBar <ToDo>
12. Enchant Hyprland config and window behaviour
13. Fix the Dynamic Color Theme for Fish and Kitty
14. Add a shortcut to move window across the workspaces

### Notes on 4-6
- 4: `widgets/WorkspaceBar.qml` renders terminals with the Nerd Font glyph
  `U+F120` (nf-fa-terminal) via `HyprlandIPC.isTerminalClass()`; `kitty` is
  also mapped to the `kitty` icon in `iconMap` for AppIcon.
- 5: `hypr/hyprland/execs.conf` runs `exec-once = qs -c material-hyprland/qt`
  (correct path for the installed layout) and logs to
  `~/.cache/material-hyprland/quickshell.log`; `scripts/toggle_qs.sh` restarted
  with the same config.
- 6: `$terminal = kitty -e fish` in `hypr/hyprland/shortcuts.conf`; `$qs`
  points at `material-hyprland/qt`.

### Notes on 7-10
- 7: Wallpaper picker lives in `shell/qt/windows/WallpaperPicker.qml` (a wide
  M3 dialog with a thumbnail grid, "Random" and "Refresh"), backed by the new
  `core/WallpaperService.qml` singleton and `shell/qt/scripts/wallpaper-scan.sh`.
  `hypr/scripts/wallpaper_manager.py` gained `list` / `current` subcommands.
  Bound to `SUPER CTRL + T` (`toggleWallpaper` IPC) and reachable from
  QuickSettings and Settings → Appearance.
- 8: Light/dark now reaches every app. Flipping the theme in Settings/Quick
  Settings writes the mode to `~/.local/state/theme/mode` and re-runs
  `apply-theme.sh --mode <light|dark> --contrast …`, which regenerates kitty,
  fish, starship **and** GTK colours. New matugen templates
  `theme/templates/gtk-3.0.css` / `gtk-4.0.css` write straight into
  `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css`, and the script
  flips `gsettings … color-scheme`, so Nemo and other GTK apps follow. The mode
  is persisted, so wallpaper changes via `wallpaper_manager.py` keep it too.
- 9: `$launcher` in `hypr/hyprland/shortcuts.conf` now invokes the in-shell
  Material 3 launcher (`$qs ipc call shell openLauncher`, `windows/Launcher.qml`)
  on `SUPER SPACE`; fuzzel remains available as `$fallback_launcher`.
- 10: `SUPER ALT + L` → `$qs ipc call shell toggleAiSidebar` opens the AI
  assistant drawer (`windows/AiSidebar.qml` + `widgets/AiChatWidget.qml`).

## Theme work (this iteration)
5. Dynamic Material 3 theme for kitty + fish via matugen <Completed>
6. Switch terminal/UI fonts to JetBrainsMono Nerd Font <Completed>
7. Installer installs matugen config/templates, kitty/fish/starship configs and seeds the palette <Completed>
8. Wallpaper change triggers `apply-theme.sh` so the palette follows the wallpaper <Completed>
9. `theme` fish helper + `scripts/apply-theme.sh` for manual regeneration <Completed>
10. Optional: expose theme mode (dark/light) + contrast in SettingsWindow <Completed>
11. Optional: generate fuzzel / gtk / hyprland border colours from the same palette <In Progress>


