import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../core"

// AI companion chat, driven by the Python backend through AiBridge. Header
// (portrait / name / expression), transcript, typing indicator, composer and a
// transient error banner. Navigation (history, new chat, settings) lives in the
// AiSidebar header; this widget exposes `newChat()` for it.
M3Card {
    id: root
    implicitHeight: M3Tokens.dp(400)

    signal characterRequested()          // header tapped -> host opens the picker

    // Local message model, mirrored from AiBridge.replyReceived / chatLoaded.
    ListModel { id: messages }

    function seedGreeting() {
        if (messages.count === 0 && AiBridge.greeting !== "")
            messages.append({ role: "assistant", body: AiBridge.greeting })
    }
    // Fresh conversation (backend reset + greeting bubble).
    function newChat() {
        messages.clear()
        AiBridge.resetChat()
        seedGreeting()
    }
    function _showError(msg) { errorText = msg; errorTimer.restart() }
    property string errorText: ""

    Connections {
        target: AiBridge
        function onReplyReceived(payload) {
            messages.append({ role: "assistant", body: payload.text || "…" })
        }
        function onChatLoaded(transcript) {
            messages.clear()
            for (const m of transcript) messages.append({ role: m.role, body: m.text })
        }
        function onErrorRaised(message) { root._showError(message) }
        // Character switched / edited: the backend clears the transcript.
        function onCharacterIdChanged() { messages.clear(); root.seedGreeting() }
        function onCharacterNameChanged() { messages.clear(); root.seedGreeting() }
        function onGreetingChanged() { messages.clear(); root.seedGreeting() }
        function onBusyChanged() { Qt.callLater(list.positionViewAtEnd) }
    }
    Component.onCompleted: seedGreeting()

    Timer { id: errorTimer; interval: 6000; onTriggered: root.errorText = "" }

    function send(text) {
        text = text.trim()
        if (text === "" || AiBridge.busy || !AiBridge.ready) return
        messages.append({ role: "user", body: text })
        AiBridge.send(text)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: M3Tokens.dp(8)

        // ---- Header: portrait + name + expression ---------------------------
        Item {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight
            RowLayout {
                id: headerRow
                anchors.fill: parent
                spacing: M3Tokens.dp(10)
                Portrait {
                    size: M3Tokens.dp(40)
                    source: AiBridge.expressionUrl
                    emoji: AiBridge.portraitEmoji
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    spacing: 0
                    M3Text {
                        Layout.fillWidth: true
                        text: AiBridge.characterName !== "" ? AiBridge.characterName : "Assistant"
                        type: "title"
                    }
                    M3Text {
                        Layout.fillWidth: true
                        text: AiBridge.ready ? (AiBridge.expression || "neutral") : "connecting…"
                        type: "caption"; muted: true
                    }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.characterRequested() }
        }

        // ---- Transcript ------------------------------------------------------
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: M3Tokens.dp(6)
            model: messages
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: Qt.callLater(positionViewAtEnd)
            delegate: Item {
                id: rowItem
                required property string role
                required property string body
                width: list.width
                height: bubble.height
                Rectangle {
                    id: bubble
                    readonly property bool mine: rowItem.role === "user"
                    x: mine ? rowItem.width - width : 0
                    width: Math.min(msg.implicitWidth + M3Tokens.dp(24), rowItem.width * 0.88)
                    height: msg.implicitHeight + M3Tokens.dp(16)
                    radius: M3Tokens.cornerRadiusMd
                    color: mine ? M3Theme.primaryContainer : M3Theme.surfaceContainerHigh
                    M3Text {
                        id: msg
                        x: M3Tokens.dp(12); y: M3Tokens.dp(8); width: bubble.width - M3Tokens.dp(24)
                        text: rowItem.body === "" ? "…" : rowItem.body
                        wrapMode: Text.Wrap; elide: Text.ElideNone
                        color: bubble.mine ? M3Theme.primaryContainerFg : M3Theme.fg
                    }
                }
            }
            footer: Item {
                width: list.width
                height: AiBridge.busy ? M3Tokens.dp(42) : 0
                visible: AiBridge.busy
                TypingIndicator { y: M3Tokens.dp(6); visible: AiBridge.busy }
            }
        }

        // ---- Transient error banner -----------------------------------------
        Rectangle {
            Layout.fillWidth: true
            visible: root.errorText !== ""
            implicitHeight: errLabel.implicitHeight + M3Tokens.dp(16)
            radius: M3Tokens.cornerRadiusMd
            color: M3Theme.errorContainer
            RowLayout {
                anchors { fill: parent; leftMargin: M3Tokens.dp(12); rightMargin: M3Tokens.dp(4) }
                M3Icon { name: "error"; size: M3Tokens.dp(18); color: M3Theme.errorContainerFg }
                M3Text {
                    id: errLabel
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: root.errorText; color: M3Theme.errorContainerFg
                    wrapMode: Text.Wrap; elide: Text.ElideNone; type: "caption"
                }
                M3IconButton { icon: "close"; size: M3Tokens.dp(28); onClicked: root.errorText = "" }
            }
        }

        // ---- Composer --------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: M3Tokens.dp(6)
            M3TextField {
                id: input
                Layout.fillWidth: true; Layout.minimumWidth: 0
                placeholderText: !AiBridge.ready ? "Backend starting…"
                               : AiBridge.busy ? "Thinking…"
                               : "Message…"
                enabled: AiBridge.ready && !AiBridge.busy
                onAccepted: { root.send(text); text = "" }
            }
            M3IconButton {
                icon: "send"; filled: true; size: M3Tokens.dp(44)
                enabled: AiBridge.ready && !AiBridge.busy
                onClicked: { root.send(input.text); input.text = "" }
            }
        }
    }
}
