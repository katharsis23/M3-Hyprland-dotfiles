import QtQuick
import QtQuick.Layouts
import "../components"
import "../widgets"
import "../theme"
import "../core"

// Power / session popup. Opened from the bar's power button (End island) and
// hosted by OverlayLayer exactly like the Quick Settings and Calendar panels.
M3Panel {
    id: panel
    readonly property int pad: M3Tokens.dp(16)
    implicitWidth: M3Tokens.dp(300)
    // Height is derived from the concrete body metrics rather than the nested
    // layout's (unreliable) implicitHeight, so the popup always has a real size.
    implicitHeight: body.implicitHeight + pad * 2

    ColumnLayout {
        id: body
        anchors { fill: parent; margins: panel.pad }
        spacing: M3Tokens.dp(12)

        M3Text { Layout.fillWidth: true; text: "Power"; type: "title" }

        ShutDownWidget { Layout.fillWidth: true }
    }
}
