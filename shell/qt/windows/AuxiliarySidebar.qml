import QtQuick
import QtQuick.Layouts
import "../components"
import "../widgets"
import "../theme"
import "../core"

// Drawer: system telemetry, media controls, local LLM chat. Scrolls when the
// screen is short; heavy widgets only run while the drawer is open.
M3Panel {
    id: panel
    transform: Translate { x: (1 - panel.reveal) * M3Tokens.dp(28) }

    ColumnLayout {
        anchors { fill: parent; margins: M3Tokens.dp(14) }
        spacing: M3Tokens.dp(10)
        RowLayout {
            Layout.fillWidth: true
            M3Text { Layout.fillWidth: true; text: "Sidebar"; type: "headline"
                     font.pixelSize: Typography.titleLarge }
            M3IconButton { icon: "close"; tooltip: "Close"; onClicked: ConfigProvider.closeAll() }
        }
        M3Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: width; contentHeight: stack.implicitHeight
            ColumnLayout {
                id: stack
                width: parent.width - M3Tokens.dp(6)
                spacing: M3Tokens.dp(10)
                CpuRamWidget { Layout.fillWidth: true; active: panel.open }
                MediaPlayerWidget { Layout.fillWidth: true; active: panel.open }
                AiChatWidget {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(M3Tokens.dp(320), Math.min(M3Tokens.dp(460), panel.height * 0.55))
                }
            }
        }
    }
}
