import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../core"

// Character list. Each card loads its own info through AiBridge.characterInfo.
Item {
    id: root
    signal selected(string id)           // character activated -> host returns to chat
    signal editRequested(string id)
    signal createRequested()

    property string pendingDeleteId: ""
    property string pendingDeleteName: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: M3Tokens.spaceSm

        M3Button {
            Layout.fillWidth: true
            text: "New character"; icon: "add"; variant: "tonal"
            enabled: AiBridge.ready
            onClicked: root.createRequested()
        }

        M3Flickable {
            id: flick
            Layout.fillWidth: true; Layout.fillHeight: true
            contentHeight: col.implicitHeight
            ColumnLayout {
                id: col
                width: flick.width - M3Tokens.dp(6)
                spacing: M3Tokens.spaceSm
                Repeater {
                    model: AiBridge.characterIds
                    delegate: Rectangle {
                        id: card
                        required property string modelData
                        property var info: ({})
                        readonly property bool current: modelData === AiBridge.characterId
                        readonly property string excerpt: {
                            const p = (info.personality || "").replace(/\s+/g, " ").trim()
                            return p.length > 90 ? p.substring(0, 90) + "…" : p
                        }
                        Layout.fillWidth: true
                        implicitHeight: M3Tokens.dp(84)
                        radius: current ? M3Tokens.cornerRadiusLg : M3Tokens.cornerRadiusXl
                        color: current ? M3Theme.primaryContainer : M3Theme.surfaceContainerHighest
                        Behavior on color { ColorAnimation { duration: M3Tokens.durationMedium } }

                        Component.onCompleted: AiBridge.characterInfo(modelData, (r) => { if (r) card.info = r })

                        RowLayout {
                            anchors { fill: parent; margins: M3Tokens.dp(10) }
                            spacing: M3Tokens.dp(8)

                            // Tapping the main area activates the character. The action buttons
                            // are siblings (not children) so their taps never reach this handler.
                            Item {
                                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: M3Tokens.dp(10)
                                    Portrait {
                                        size: M3Tokens.dp(52)
                                        source: card.info.thumb || ""
                                        emoji: card.info.emoji || "🙂"
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 0
                                        M3Text {
                                            Layout.fillWidth: true
                                            text: card.info.name || card.modelData; type: "title"
                                            color: card.current ? M3Theme.primaryContainerFg : M3Theme.fg
                                        }
                                        M3Text {
                                            Layout.fillWidth: true
                                            text: card.excerpt; type: "caption"
                                            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                                            color: card.current ? M3Theme.primaryContainerFg : M3Theme.fgMuted
                                        }
                                    }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { AiBridge.selectCharacter(card.modelData); root.selected(card.modelData) } }
                            }
                            M3IconButton {
                                icon: card.current ? "check_circle" : "radio_button_unchecked"
                                size: M3Tokens.dp(32); toggled: card.current
                                tooltip: card.current ? "Active" : "Set active"
                                onClicked: { AiBridge.selectCharacter(card.modelData); root.selected(card.modelData) }
                            }
                            M3IconButton {
                                icon: "edit"; size: M3Tokens.dp(32); tooltip: "Edit"
                                onClicked: root.editRequested(card.modelData)
                            }
                            M3IconButton {
                                visible: card.info.custom === true
                                icon: "delete"; size: M3Tokens.dp(32); tooltip: "Delete"
                                onClicked: {
                                    root.pendingDeleteId = card.modelData
                                    root.pendingDeleteName = card.info.name || card.modelData
                                    confirm.open = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Delete confirmation ------------------------------------------------
    Rectangle {
        anchors.fill: parent
        visible: confirm.open || confirm.reveal > 0.001
        color: M3Theme.scrim
        opacity: confirm.reveal
        radius: M3Tokens.cornerRadiusLg
        MouseArea { anchors.fill: parent; onClicked: confirm.open = false }
    }
    M3Dialog {
        id: confirm
        title: "Delete character"; icon: "delete"
        width: Math.min(root.width - M3Tokens.dp(16), M3Tokens.dp(340))
        height: M3Tokens.dp(220)
        anchors.centerIn: parent
        onCloseRequested: open = false
        ColumnLayout {
            anchors.fill: parent
            spacing: M3Tokens.spaceMd
            M3Text {
                Layout.fillWidth: true
                text: "Delete “" + root.pendingDeleteName + "”? This cannot be undone."
                wrapMode: Text.Wrap; elide: Text.ElideNone
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                M3Button { text: "Cancel"; variant: "text"; onClicked: confirm.open = false }
                M3Button {
                    text: "Delete"; variant: "filled"
                    onClicked: {
                        AiBridge.deleteCharacter(root.pendingDeleteId, () => {})
                        confirm.open = false
                    }
                }
            }
        }
    }
}
