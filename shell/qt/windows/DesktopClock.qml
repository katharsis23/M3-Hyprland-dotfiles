import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../core"
import "../components"

// Ambient clock on the bottom layer. Click-through (empty input mask) and sized
// from the screen, so it fits any resolution.
PanelWindow {
    id: win
    visible: ConfigProvider.desktopClock
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    mask: Region {}
    WlrLayershell.namespace: "m3shell-clock"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    SystemClock { id: clk; precision: SystemClock.Seconds }
    readonly property real base: Math.min(M3Tokens.dp(168), (screen ? screen.height : 1080) * 0.17)

    ColumnLayout {
        anchors.centerIn: parent
        spacing: M3Tokens.dp(4)
        M3Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clk.date, ConfigProvider.clock24h ? "HH:mm" : "h:mm AP")
            font.pixelSize: win.base; font.weight: Font.Thin; elide: Text.ElideNone
            color: M3Theme.alpha(M3Theme.fg, 0.88)
            style: Text.Raised; styleColor: M3Theme.alpha(M3Theme.surface, 0.55)
        }
        M3Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clk.date, "dddd, d MMMM")
            font.pixelSize: Math.max(M3Tokens.dp(16), win.base * 0.17); font.weight: Font.Light; elide: Text.ElideNone
            color: M3Theme.alpha(M3Theme.fg, 0.75)
            style: Text.Raised; styleColor: M3Theme.alpha(M3Theme.surface, 0.55)
        }
    }
}
