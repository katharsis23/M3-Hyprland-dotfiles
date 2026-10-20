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

    // Active view: chat | history | characters | editor | settings
    property string page: "chat"
    property string editId: ""              // character being edited ("" = create)

    readonly property var titles: ({
        chat: "Assistant", history: "History", characters: "Characters",
        editor: panel.editId === "" ? "New character" : "Edit character", settings: "Settings"
    })
    // Pages that need a live backend; settings stays reachable for diagnostics.
    readonly property bool gated: !AiBridge.ready && page !== "settings"

    function back() {
        if (page === "editor") page = "characters"
        else page = "chat"
    }
    // Always start on the chat when the drawer reopens.
    onOpenChanged: if (!open) page = "chat"

    ColumnLayout {
        anchors { fill: parent; margins: M3Tokens.dp(14) }
        spacing: M3Tokens.dp(10)

        // ---- Header -----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: M3Tokens.dp(4)
            M3IconButton {
                visible: panel.page !== "chat"
                icon: "arrow_back"; tooltip: "Back"
                onClicked: panel.back()
            }
            M3Icon {
                visible: panel.page === "chat"
                Layout.leftMargin: M3Tokens.dp(6); Layout.rightMargin: M3Tokens.dp(4)
                name: "smart_toy"; size: M3Tokens.dp(22); color: M3Theme.primaryText
            }
            M3Text {
                Layout.fillWidth: true; Layout.minimumWidth: 0
                text: panel.titles[panel.page]; type: "headline"
                font.pixelSize: Typography.titleLarge
            }
            M3IconButton {
                visible: panel.page === "chat"
                icon: "history"; tooltip: "History"
                onClicked: panel.page = "history"
            }
            M3IconButton {
                visible: panel.page === "chat"
                icon: "add_comment"; tooltip: "New chat"
                enabled: AiBridge.ready
                onClicked: chat.newChat()
            }
            M3IconButton {
                visible: panel.page === "chat"
                icon: "settings"; tooltip: "Settings"
                onClicked: panel.page = "settings"
            }
            M3IconButton { icon: "close"; tooltip: "Close"; onClicked: ConfigProvider.closeAll() }
        }

        // ---- Views ---------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // The chat stays instantiated so its transcript survives page switches.
            AiChatWidget {
                id: chat
                anchors.fill: parent
                visible: panel.page === "chat" && !panel.gated
                onCharacterRequested: panel.page = "characters"
            }
            Loader {
                anchors.fill: parent
                active: panel.page === "history" && !panel.gated
                visible: active
                sourceComponent: ChatHistoryView { onOpened: panel.page = "chat" }
            }
            Loader {
                anchors.fill: parent
                active: panel.page === "characters" && !panel.gated
                visible: active
                sourceComponent: CharacterPicker {
                    onSelected: panel.page = "chat"
                    onEditRequested: (id) => { panel.editId = id; panel.page = "editor" }
                    onCreateRequested: { panel.editId = ""; panel.page = "editor" }
                }
            }
            Loader {
                anchors.fill: parent
                active: panel.page === "editor" && !panel.gated
                visible: active
                sourceComponent: CharacterEditor {
                    characterId: panel.editId
                    onSaved: panel.page = "chat"          // saveCharacter reselects the character
                    onCancelled: panel.page = "characters"
                }
            }
            Loader {
                anchors.fill: parent
                active: panel.page === "settings"
                visible: active
                sourceComponent: AiSettingsView { onOpenCharacters: panel.page = "characters" }
            }

            // ---- Connecting skeleton / failure state ------------------------------
            ColumnLayout {
                anchors { fill: parent; margins: M3Tokens.dp(4) }
                visible: panel.gated
                spacing: M3Tokens.dp(10)

                RowLayout {
                    visible: AiBridge.starting
                    Layout.fillWidth: true
                    spacing: M3Tokens.dp(10)
                    Rectangle { Layout.preferredWidth: M3Tokens.dp(40); Layout.preferredHeight: M3Tokens.dp(40)
                                radius: width / 2; color: M3Theme.surfaceContainerHigh; opacity: pulse.value }
                    ColumnLayout {
                        spacing: M3Tokens.dp(6)
                        Rectangle { Layout.preferredWidth: M3Tokens.dp(120); Layout.preferredHeight: M3Tokens.dp(12)
                                    radius: height / 2; color: M3Theme.surfaceContainerHigh; opacity: pulse.value }
                        Rectangle { Layout.preferredWidth: M3Tokens.dp(70); Layout.preferredHeight: M3Tokens.dp(10)
                                    radius: height / 2; color: M3Theme.surfaceContainerHigh; opacity: pulse.value }
                    }
                }
                Repeater {
                    model: AiBridge.starting ? 3 : 0
                    delegate: Rectangle {
                        required property int index
                        Layout.preferredWidth: parent.width * (index % 2 === 0 ? 0.7 : 0.5)
                        Layout.alignment: index % 2 === 0 ? Qt.AlignLeft : Qt.AlignRight
                        Layout.preferredHeight: M3Tokens.dp(44)
                        radius: M3Tokens.cornerRadiusMd
                        color: M3Theme.surfaceContainerHigh; opacity: pulse.value
                    }
                }
                M3Text {
                    Layout.fillWidth: true; Layout.topMargin: M3Tokens.dp(8)
                    visible: AiBridge.starting
                    text: "Connecting…"; muted: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.fillHeight: true; visible: !AiBridge.starting }
                M3Icon {
                    visible: !AiBridge.starting
                    Layout.alignment: Qt.AlignHCenter
                    name: "cloud_off"; size: M3Tokens.dp(40); color: M3Theme.fgMuted
                }
                M3Text {
                    visible: !AiBridge.starting
                    Layout.fillWidth: true
                    text: "Assistant backend is not running"; type: "title"
                    horizontalAlignment: Text.AlignHCenter
                }
                M3Text {
                    visible: !AiBridge.starting && AiBridge.lastError !== ""
                    Layout.fillWidth: true
                    text: AiBridge.lastError; color: M3Theme.error; type: "caption"
                    wrapMode: Text.Wrap; elide: Text.ElideNone
                    horizontalAlignment: Text.AlignHCenter
                }
                M3Button {
                    visible: !AiBridge.starting
                    Layout.alignment: Qt.AlignHCenter
                    text: "Retry"; icon: "refresh"; variant: "filled"
                    onClicked: AiBridge.restart()
                }
                Item { Layout.fillHeight: true; visible: !AiBridge.starting }
                Item { Layout.fillHeight: true; visible: AiBridge.starting }
            }

            Item {                                   // skeleton pulse driver
                id: pulse
                visible: false
                property real value: 0.5
                SequentialAnimation on value {
                    running: panel.gated && AiBridge.starting && M3Tokens.motion
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.5; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
