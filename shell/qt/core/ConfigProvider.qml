pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// UI state + persisted settings ($XDG_CONFIG_HOME/material-hyprland/shell.json).
Singleton {
    id: root

    // ---- Appearance -------------------------------------------------------
    property string barPosition: "top"      // top | bottom | left | right
    property string barMode: "float"        // float | hug
    property color  seedColor: "#6750A4"
    property bool   darkMode: true
    property real   uiScale: 1.0            // 0.75 .. 1.75

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
    property bool dnd: false
    property bool nightLight: false
    // Overlays open on exactly one screen: the one the user acted on.
    property string overlayScreen: ""

    readonly property bool dialogOpen: settingsOpen || shortcutsOpen
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
            darkMode: darkMode, uiScale: uiScale, clockSeconds: clockSeconds,
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
    onDarkModeChanged: _dirty()
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

    function resetDefaults() {
        barPosition = "top"; barMode = "float"; seedColor = "#6750A4"; darkMode = true
        uiScale = 1.0; clockSeconds = false; clock24h = true; animations = true
        blurEnabled = true; desktopClock = true; aiModel = "llama3"
        clockX = 0.5; clockY = 0.5; clockScale = 1.0
    }
}
