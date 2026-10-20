import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../core"

// Past conversations. Opening one loads it and hands control back to the chat.
Item {
    id: root
    signal opened()                       // a chat was requested / a new chat started

    Component.onCompleted: AiBridge.refreshChats()

    function _when(v) {
        if (v === undefined || v === null || v === "") return ""
        const d = typeof v === "number" ? new Date(v < 1e12 ? v * 1000 : v) : new Date(v)
        return isNaN(d.getTime()) ? String(v) : d.toLocaleString(Qt.locale(), Locale.ShortFormat)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: M3Tokens.spaceSm

        M3Button {
            Layout.fillWidth: true
            text: "New chat"; icon: "add_comment"; variant: "tonal"
            enabled: AiBridge.ready
            onClicked: { AiBridge.resetChat(); root.opened() }
        }

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: M3Tokens.spaceSm
                model: AiBridge.chats
                boundsBehavior: Flickable.StopAtBounds
                delegate: M3Tile {
                    required property var modelData
                    width: list.width
                    icon: "chat"
                    label: modelData.preview && modelData.preview !== "" ? modelData.preview : "Empty conversation"
                    detail: [root._when(modelData.updated),
                             (modelData.count !== undefined ? modelData.count + " messages" : "")]
                            .filter(x => x !== "").join(" · ")
                    active: modelData.id === AiBridge.chatId
                    onTapped: { AiBridge.loadChat(modelData.id); root.opened() }
                }
            }
            M3Text {
                anchors.centerIn: parent
                visible: AiBridge.chats.length === 0
                text: "No conversations yet"; muted: true
            }
        }
    }
}
