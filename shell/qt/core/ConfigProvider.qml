pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."

// UI state + persisted settings ($XDG_CONFIG_HOME/material-hyprland/shell.json).
Singleton {
    id: root

    // ---- Appearance -------------------------------------------------------
    property string barPosition: "top"      // top | bottom | left | right
    property string barMode: "float"        // float | hug
    property color  seedColor: "#6750A4"
    property bool   darkMode: true
    property real   uiScale: 1.0            // 0.75 .. 1.75
    // matugen contrast (-1..1). 0 is the Material default; exposed in settings.
    property real   themeContrast: 0.0

    // ---- Behaviour --------------------------------------------------------
    property bool   clockSeconds: false
    property bool   clock24h: true
    property bool   animations: true
    property bool   blurEnabled: true
    property bool   desktopClock: true
    property string swwwTransition: "grow"
    property string aiModel: "llama3"

    // ---- Transient UI state ----------------------------------------------
    property bool quickSettingsOpen: false
    property bool calendarOpen: false
    property bool sidebarOpen: false
    // Separate LEFT sidebar that hosts the AI assistant.
    property bool leftSidebarOpen: false
    property bool settingsOpen: false
    property bool shortcutsOpen: false
    property bool wallpaperOpen: false
    property bool dnd: false
    property bool nightLight: false
    // Overlays open on exactly one screen: the one the user acted on.
    property string overlayScreen: ""

    readonly property bool dialogOpen: settingsOpen || shortcutsOpen || wallpaperOpen
    readonly property bool anyOpen: quickSettingsOpen || calendarOpen || sidebarOpen
                                    || leftSidebarOpen || dialogOpen

    // ---- Desktop clock placement (draggable + resizable) ------------------
    // Normalised position (0..1) of the clock centre and a size multiplier,
    // persisted so the user can drag/resize the ambient clock and keep it.
    property real clockX: 0.5
    property real clockY: 0.5
    property real clockScale: 1.0

    function focusedScreenName() {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }
    function closeAll() {
        quickSettingsOpen = false; calendarOpen = false; sidebarOpen = false
        leftSidebarOpen = false; settingsOpen = false; shortcutsOpen = false
        wallpaperOpen = false
    }
    function _toggle(prop, screenName) {
        const wasOpen = root[prop]
        closeAll()
        if (!wasOpen) {
            overlayScreen = (screenName && screenName !== "") ? screenName : focusedScreenName()
            root[prop] = true
        }
    }
    function toggleQuickSettings(s) { _toggle("quickSettingsOpen", s) }
    function toggleCalendar(s)      { _toggle("calendarOpen", s) }
    function toggleSidebar(s)       { _toggle("sidebarOpen", s) }
    function toggleLeftSidebar(s)   { _toggle("leftSidebarOpen", s) }
    function toggleSettings(s)      { _toggle("settingsOpen", s) }
    function toggleShortcuts(s)     { _toggle("shortcutsOpen", s) }
    function toggleWallpaper(s)     { _toggle("wallpaperOpen", s); if (wallpaperOpen) WallpaperService.refresh() }

    // ---- Persistence ------------------------------------------------------
    readonly property string settingsDir:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/material-hyprland"
    readonly property string settingsPath: settingsDir + "/shell.json"
    property bool _loaded: false

    Process { command: ["mkdir", "-p", root.settingsDir]; running: true }

    FileView {
        id: store
        path: root.settingsPath
        atomicWrites: true
        watchChanges: false
        onLoaded: root.applyStored(store.text())
        onLoadFailed: root._loaded = true
    }

    function applyStored(raw) {
        try {
            const o = JSON.parse(raw)
            if (["top", "bottom", "left", "right"].indexOf(o.barPosition) >= 0) barPosition = o.barPosition
            if (["float", "hug"].indexOf(o.barMode) >= 0) barMode = o.barMode
            if (typeof o.seedColor === "string") seedColor = o.seedColor
            if (typeof o.darkMode === "boolean") darkMode = o.darkMode
            if (typeof o.themeContrast === "number") themeContrast = Math.max(-1, Math.min(1, o.themeContrast))
            if (typeof o.uiScale === "number") uiScale = Math.max(0.75, Math.min(1.75, o.uiScale))
            if (typeof o.clockSeconds === "boolean") clockSeconds = o.clockSeconds
            if (typeof o.clock24h === "boolean") clock24h = o.clock24h
            if (typeof o.animations === "boolean") animations = o.animations
            if (typeof o.blurEnabled === "boolean") blurEnabled = o.blurEnabled
            if (typeof o.desktopClock === "boolean") desktopClock = o.desktopClock
            if (typeof o.swwwTransition === "string") swwwTransition = o.swwwTransition
            if (typeof o.aiModel === "string" && o.aiModel !== "") aiModel = o.aiModel
            if (typeof o.clockX === "number") clockX = Math.max(0, Math.min(1, o.clockX))
            if (typeof o.clockY === "number") clockY = Math.max(0, Math.min(1, o.clockY))
            if (typeof o.clockScale === "number") clockScale = Math.max(0.5, Math.min(3.0, o.clockScale))
        } catch (e) { /* missing or corrupt file: keep defaults */ }
        _loaded = true
    }

    function serialize() {
        return JSON.stringify({
            barPosition: barPosition, barMode: barMode, seedColor: "" + seedColor,
            darkMode: darkMode, themeContrast: themeContrast, uiScale: uiScale, clockSeconds: clockSeconds,
            clock24h: clock24h, animations: animations, blurEnabled: blurEnabled,
            desktopClock: desktopClock, swwwTransition: swwwTransition, aiModel: aiModel,
            clockX: clockX, clockY: clockY, clockScale: clockScale
        }, null, 2) + "\n"
    }

    Timer { id: saveDebounce; interval: 400; onTriggered: store.setText(root.serialize()) }
    function _dirty() { if (_loaded) saveDebounce.restart() }
    onBarPositionChanged: _dirty()
    onBarModeChanged: _dirty()
    onSeedColorChanged: _dirty()
    onUiScaleChanged: _dirty()
    onClockSecondsChanged: _dirty()
    onClock24hChanged: _dirty()
    onAnimationsChanged: _dirty()
    onBlurEnabledChanged: _dirty()
    onDesktopClockChanged: _dirty()
    onSwwwTransitionChanged: _dirty()
    onAiModelChanged: _dirty()
    onClockXChanged: _dirty()
    onClockYChanged: _dirty()
    onClockScaleChanged: _dirty()
    onThemeContrastChanged: { _dirty(); if (_loaded) themeDebounce.restart() }

    // ---- Global theme mode (dark/light) for *every* application ----------
    // The Quickshell UI re-derives its palette from darkMode automatically, but
    // kitty, fish, starship and GTK apps are recoloured by matugen. When the
    // user flips the theme we persist the mode and regenerate those files so
    // the terminal and file manager match the shell. Best-effort: a missing
    // matugen never blocks the shell.
    readonly property string themeStateDir:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/theme"

    Process { id: mkThemeDirs; command: ["mkdir", "-p", root.themeStateDir] }

    // Persist the mode so wallpaper changes (wallpaper_manager.py) keep it.
    Process {
        id: themeModeWrite
        property string mode: "dark"
        command: ["bash", "-c", 'mkdir -p "$2"; printf "%s\\n" "$1" > "$2/mode"', "--", mode, root.themeStateDir]
    }

    // Resolve and run apply-theme.sh (installed hypr scripts first, then the
    // repo copy next to the shell) with the chosen mode + contrast. The script
    // also rewrites the mode file, so lines below stay in sync.
    Process { id: applyThemeProc }

    Timer { id: themeDebounce; interval: 300; onTriggered: root._applyThemeMode() }

    function _applyThemeMode() {
        const mode = darkMode ? "dark" : "light"
        mkThemeDirs.running = true
        themeModeWrite.mode = mode
        themeModeWrite.running = true
        const repoHelper = Quickshell.shellPath("../../hypr/scripts/apply-theme.sh") || ""
        applyThemeProc.exec(["bash", "-c",
            'set -e; ' +
            'H="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/apply-theme.sh"; ' +
            '[ -x "$H" ] || H="$1"; ' +
            '[ -x "$H" ] || exit 0; ' +
            '"$H" --mode "$2" --contrast "$3"',
            "--", repoHelper, mode, "" + themeContrast])
    }

    Timer { id: applyThemeOnStart; interval: 1500; onTriggered: if (root._loaded) root._applyThemeMode() }

    // Only regenerate on user-driven changes (after the initial load settles).
    onDarkModeChanged: { _dirty(); if (_loaded) themeDebounce.restart() }

    function resetDefaults() {
        barPosition = "top"; barMode = "float"; seedColor = "#6750A4"; darkMode = true
        themeContrast = 0.0
        uiScale = 1.0; clockSeconds = false; clock24h = true; animations = true
        blurEnabled = true; desktopClock = true; aiModel = "llama3"
        clockX = 0.5; clockY = 0.5; clockScale = 1.0
    }
}
