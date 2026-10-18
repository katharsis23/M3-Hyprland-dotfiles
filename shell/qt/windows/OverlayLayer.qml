import QtQuick
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../core"

// ONE full-screen overlay per monitor hosting every popup, the drawer and the
// dialogs. Because they all live in one known-size surface, every panel is
// positioned next to the bar (whichever edge it is on) and clamped to the
// screen — nothing can open off-screen. Invisible (and input-transparent)
// while nothing is open.
PanelWindow {
    id: ov
    readonly property string screenName: screen ? screen.name : ""
    readonly property bool mine: ConfigProvider.overlayScreen === screenName
    readonly property bool shown: ConfigProvider.anyOpen && mine
    property real reveal: shown ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: M3Tokens.durationMedium; easing.type: M3Tokens.easing } }

    readonly property string pos: ConfigProvider.barPosition
    readonly property bool vertical: pos === "left" || pos === "right"
    readonly property int edge: M3Tokens.barEdgeInset          // space taken by the bar on its edge
    readonly property int side: M3Tokens.dp(10)
    readonly property int maxW: Math.max(M3Tokens.dp(160), width - side - (vertical ? edge : side))
    readonly property int maxH: Math.max(M3Tokens.dp(160), height - side - (vertical ? side : edge))

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(v, Math.max(lo, hi))) }
    // popups hang off the bar's end group (right / bottom corner)
    function popupX(w) {
        const x = pos === "left" ? edge : pos === "right" ? width - w - edge : width - w - side
        return clamp(x, side, width - w - side)
    }
    function popupY(h) {
        const y = pos === "top" ? edge : pos === "bottom" ? height - h - edge : height - h - side
        return clamp(y, side, height - h - side)
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: reveal > 0.001
    WlrLayershell.namespace: "m3shell-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: !shown ? WlrKeyboardFocus.None
        : (ConfigProvider.dialogOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand)

    FocusScope {
        anchors.fill: parent
        focus: ov.shown
        Keys.onEscapePressed: ConfigProvider.closeAll()

        Rectangle {                                    // dim behind dialogs only
            anchors.fill: parent
            color: M3Theme.scrim
            opacity: (ov.mine && ConfigProvider.dialogOpen) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: M3Tokens.durationMedium } }
        }
        MouseArea { anchors.fill: parent; onClicked: ConfigProvider.closeAll() }   // click outside closes

        QuickSettingsPanel {
            open: ConfigProvider.quickSettingsOpen && ov.mine
            width: Math.min(M3Tokens.dp(392), ov.maxW)
            height: Math.min(implicitHeight, ov.maxH)
            x: ov.popupX(width); y: ov.popupY(height)
        }
        CalendarPanel {
            open: ConfigProvider.calendarOpen && ov.mine
            width: Math.min(M3Tokens.dp(360), ov.maxW)
            height: Math.min(implicitHeight, ov.maxH)
            x: ov.popupX(width); y: ov.popupY(height)
        }
        AuxiliarySidebar {
            readonly property int topInset: ov.pos === "top" ? ov.edge : ov.side
            readonly property int bottomInset: ov.pos === "bottom" ? ov.edge : ov.side
            open: ConfigProvider.sidebarOpen && ov.mine
            width: Math.min(M3Tokens.dp(392), ov.maxW)
            height: Math.max(M3Tokens.dp(200), ov.height - topInset - bottomInset)
            x: ov.width - width - (ov.pos === "right" ? ov.edge : ov.side)
            y: topInset
        }
        AiSidebar {
            readonly property int topInset: ov.pos === "top" ? ov.edge : ov.side
            readonly property int bottomInset: ov.pos === "bottom" ? ov.edge : ov.side
            open: ConfigProvider.leftSidebarOpen && ov.mine
            width: Math.min(M3Tokens.dp(392), ov.maxW)
            height: Math.max(M3Tokens.dp(200), ov.height - topInset - bottomInset)
            x: (ov.pos === "left" ? ov.edge : ov.side)
            y: topInset
        }
        SettingsWindow {
            open: ConfigProvider.settingsOpen && ov.mine
            width: Math.min(M3Tokens.dp(820), ov.width - M3Tokens.dp(32))
            height: Math.min(M3Tokens.dp(640), ov.height - M3Tokens.dp(32))
            x: (ov.width - width) / 2; y: (ov.height - height) / 2
        }
        ShortcutWindow {
            open: ConfigProvider.shortcutsOpen && ov.mine
            width: Math.min(M3Tokens.dp(780), ov.width - M3Tokens.dp(32))
            height: Math.min(M3Tokens.dp(620), ov.height - M3Tokens.dp(32))
            x: (ov.width - width) / 2; y: (ov.height - height) / 2
        }
    }
}
