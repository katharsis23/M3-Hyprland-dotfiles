import QtQuick
import Quickshell
import Quickshell.Widgets
import "../theme"
import "../core"

// Renders the icon of an application given its Hyprland window class.
// Resolution order: known class map -> theme icon -> generic fallback.
// Shows a Material glyph if no themed pixmap can be found.
Item {
    id: root
    property string appClass: ""
    property int size: M3Tokens.dp(20)
    property color tint: M3Theme.fg

    implicitWidth: size
    implicitHeight: size

    // Absolute path resolved from the window class ("" if not found).
    readonly property string iconSource: HyprlandIPC.iconForClass(appClass)

    IconImage {
        id: img
        anchors.centerIn: parent
        implicitSize: root.size
        source: root.iconSource
        visible: root.iconSource !== "" && status === Image.Ready
    }

    // Fallback glyph when no icon pixmap is available.
    M3Icon {
        anchors.centerIn: parent
        visible: !img.visible
        name: "apps"
        size: root.size
        color: root.tint
    }
}
