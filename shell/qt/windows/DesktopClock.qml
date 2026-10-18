import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../core"
import "../components"

// Ambient clock on the bottom layer. Draggable (grab it and move it anywhere)
// and resizable (mouse wheel). Position and size persist via
// ConfigProvider.clockX / clockY / clockScale. Input is masked to the clock
// itself, so the rest of the desktop stays click-through.
PanelWindow {
    id: win
    visible: ConfigProvider.desktopClock
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.namespace: "m3shell-clock"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    SystemClock { id: clk; precision: SystemClock.Seconds }

    // Base time font size scales with the screen AND the user-chosen scale.
    readonly property real autoBase: Math.min(M3Tokens.dp(168), (screen ? screen.height : 1080) * 0.17)
    readonly property real base: autoBase * ConfigProvider.clockScale

    // Clock item + its draggable/resizable surface.
    Item {
        id: clock
        // size to the content block (+ padding)
        width: block.width + M3Tokens.dp(56)
        height: block.height + M3Tokens.dp(32)
        // position from the normalised centre mapped into the screen
        x: Math.round(ConfigProvider.clockX * Math.max(0, win.width - width))
        y: Math.round(ConfigProvider.clockY * Math.max(0, win.height - height))

        Column {
            id: block
        anchors.centerIn: parent
        spacing: M3Tokens.dp(4)
        M3Text {
                anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clk.date, ConfigProvider.clock24h ? "HH:mm" : "h:mm AP")
            font.pixelSize: win.base; font.weight: Font.Thin; elide: Text.ElideNone
            color: M3Theme.alpha(M3Theme.fg, 0.88)
            style: Text.Raised; styleColor: M3Theme.alpha(M3Theme.surface, 0.55)
        }
        M3Text {
                anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clk.date, "dddd, d MMMM")
            font.pixelSize: Math.max(M3Tokens.dp(16), win.base * 0.17); font.weight: Font.Light; elide: Text.ElideNone
            color: M3Theme.alpha(M3Theme.fg, 0.75)
            style: Text.Raised; styleColor: M3Theme.alpha(M3Theme.surface, 0.55)
        }
    }

        // Drag to reposition. Updates the normalised centre live.
        DragHandler {
            id: drag
            target: null
            property real startX: 0
            property real startY: 0
            onActiveChanged: {
                if (active) { startX = ConfigProvider.clockX; startY = ConfigProvider.clockY }
}
            onTranslationChanged: {
                if (!active) return
                const dx = translation.x / Math.max(1, win.width - clock.width)
                const dy = translation.y / Math.max(1, win.height - clock.height)
                ConfigProvider.clockX = Math.max(0, Math.min(1, startX + dx))
                ConfigProvider.clockY = Math.max(0, Math.min(1, startY + dy))
            }
        }
        HoverHandler { cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }

        // Wheel to resize.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (e) => {
                const step = e.angleDelta.y > 0 ? 0.06 : -0.06
                ConfigProvider.clockScale = Math.max(0.5, Math.min(3.0, ConfigProvider.clockScale + step))
            }
        }
    }

    // Only the clock area accepts input; the rest stays click-through.
    mask: Region { item: clock }
}


