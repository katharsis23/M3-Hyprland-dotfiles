import QtQuick
import QtQuick.Layouts
import "../components"
import "../widgets"
import "../theme"
import "../core"

// Dedicated LEFT drawer hosting the local AI assistant. Kept separate from the
// right telemetry sidebar so the chat can stay open while you glance at system
// stats, and slides in from the left edge in the same Material 3 style.
M3Panel {
    id: panel
    // mirror the right sidebar's slide direction (comes in from the left)
    transform: Translate { x: -(1 - panel.reveal) * M3Tokens.dp(28) }

    ColumnLayout {
        anchors { fill: parent; margins: M3Tokens.dp(14) }
        spacing: M3Tokens.dp(10)

        RowLayout {
            Layout.fillWidth: true
            M3Icon { name: "smart_toy"; size: M3Tokens.dp(22); color: M3Theme.primaryText }
            M3Text { Layout.fillWidth: true; text: "Assistant"; type: "headline"
                     font.pixelSize: Typography.titleLarge }
            M3IconButton { icon: "close"; tooltip: "Close"; onClicked: ConfigProvider.closeAll() }
        }

        AiChatWidget {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
