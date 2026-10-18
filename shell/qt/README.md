# QuickShell Material 3 shell — v2

Run: `qs -p /path/to/shell/qt`
Needs: quickshell (recent, with `FileView.setText`), fonts **Roboto** + **Material Symbols Rounded**
(without the icon font you will see icon names as text).
Optional: `brightnessctl` (brightness slider), `hyprsunset` (night light), `curl` + Ollama (assistant),
`fuzzel`/`nemo` (launcher / files buttons in the bar).

IPC (bind in hyprland.conf): `qs ipc call shell toggleSidebar | toggleQuickSettings | toggleCalendar | toggleSettings | toggleShortcuts | closeAll`

## What changed in v2

### 1. Black text on the dark theme — fixed at the root
* Colours now come from **one pure-JS function** (`theme/Palette.js`) that returns validated `#rrggbb`
  strings. No `Qt.color()` / `Qt.rgba()` calls inside bindings, so nothing can silently become black.
* Every foreground is **picked by measured contrast** (>= 4.5:1); accents are nudged until they are >= 3:1 on surfaces.
  `node tests/test_palette.js` checks 884 pairs (17 seeds incl. black, white, yellow, grey, invalid input x light/dark).
* No property is named `on*` any more (`onSurface` -> `fg`, `onSurfaceVariant` -> `fgMuted`, `onPrimary` -> `primaryFg` ...),
  because those names look like signal handlers to QML. (`SystemServices.onBattery` -> `isOnBattery`.)
* The shell never uses a bare `Text`: everything is `M3Text` / `M3Icon`, whose colour defaults to the theme foreground.
  Text-field selection colours are themed too.

### 2. Adaptivity
* **Everything is sized with `M3Tokens.dp()`** and scales with *Settings > Appearance > Interface scale* (75-175 %).
* **Multi-monitor:** one bar, desktop clock and overlay layer per screen; popups open on the screen you clicked.
* **Bar:** top/bottom/left/right x float/hug. Start and end groups share equal space so the workspaces are truly centred.
  Modules drop out by priority on short bars (window title > date > shortcuts/Bluetooth > file manager > workspace labels);
  the clock and tray re-orient on vertical bars.
* **Overlays:** all popups, the sidebar and the dialogs live in one full-screen surface per monitor. They are placed next to
  the bar on whichever edge it is, **clamped to the screen**, and scroll when the content is taller than the screen.
* Dialogs reflow: the Settings navigation rail becomes a top row when narrow; shortcut rows stack when narrow; tiles go to one column.
* Calendar and gauges fill whatever width they are given; long text elides; light/dark and any seed colour stay readable.

### 3. UI redesign
Floating "island" bar, workspace pills with numbers (mouse wheel switches), single status cluster, M3 toggle tiles that morph
shape, ring gauges for CPU/RAM, media card with seek + elapsed time, chat with history/stop/clear, settings dialog with
navigation + palette preview + custom hex + UI scale, categorised searchable shortcuts with keycaps, glass panels with
fade/scale motion (all of it off when *Animations* is disabled).

### Other fixes found while reading your code
* `ConfigProvider` loaded from `jsonStore.data` (an adapter with no fields) so saved settings never loaded; now `FileView.text()` + `JSON.parse`, validated.
* Desktop clock had no input mask (it said click-through but wasn't); now `mask: Region {}`.
* Bar `ExclusionMode.Ignore` in float mode made windows overlap the bar; now always reserves space.
* Media position never advanced (MPRIS doesn't push it); added a 1 s refresh + click-to-seek.
* AI widget sent `{}` as a placeholder and had no history; now uses `/api/chat` with conversation history.
* Heavy widgets only poll while the sidebar is open.

## Layout
```
shell.qml                one Bar + DesktopClock + OverlayLayer per screen, IPC handler
theme/   Palette.js (colour maths) M3Theme M3Tokens Typography
core/    ConfigProvider (state+persistence) HyprlandIPC SystemServices
components/  M3Text M3Icon M3Button M3IconButton M3Card M3Switch M3Slider M3TextField M3Segmented M3Tile M3Panel M3Dialog M3Flickable
widgets/ BarIsland WorkspaceBar ServiceTray BarClock CalendarWidget ArcGauge CpuRamWidget MediaPlayerWidget AiChatWidget
windows/ TopBar OverlayLayer QuickSettingsPanel CalendarPanel AuxiliarySidebar SettingsWindow ShortcutWindow DesktopClock
tests/   test_palette.js
```
Settings/Shortcuts are now in-overlay dialogs (not separate floating windows) so they can't open off-screen or tile oddly.

## Not done / honest notes
* Not run on a live compositor from where this was written: it was statically linted (names, imports, braces, no bare `Text`)
  and the palette maths is unit-tested, but expect to fix small API differences on first launch (check `qs` log).
* Notification centre is still a placeholder (needs a notification server); *Do not disturb* is state only.
* Blur needs a Hyprland rule, e.g. `layerrule = blur, m3shell-.*` and `layerrule = ignorezero, m3shell-.*`.
