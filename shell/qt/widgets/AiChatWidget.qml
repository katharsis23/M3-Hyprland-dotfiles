import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import "../theme"
import "../core"

// Local LLM chat over Ollama's streaming /api/chat (NDJSON), with history.
M3Card {
    id: root
    property string model: ConfigProvider.aiModel
    property string endpoint: "http://localhost:11434/api/chat"
    property bool busy: false
    property int _pending: -1
    implicitHeight: M3Tokens.dp(400)

    ListModel { id: messages
        ListElement { role: "assistant"; body: "Hi! I run locally through Ollama. Ask me anything." } }

    Process {
        id: ollama
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "" || root._pending < 0) return
                try {
                    const o = JSON.parse(line)
                    if (o.error) { messages.setProperty(root._pending, "body", "Error: " + o.error); return }
                    if (o.message && o.message.content !== undefined)
                        messages.setProperty(root._pending, "body", messages.get(root._pending).body + o.message.content)
                    list.positionViewAtEnd()
                } catch (e) { /* partial line */ }
            }
        }
        onExited: {
            root.busy = false
            if (root._pending >= 0 && messages.get(root._pending).body === "")
                messages.setProperty(root._pending, "body", "No response. Is Ollama running (and is the model \"" + root.model + "\" pulled)?")
            root._pending = -1
        }
    }

    function send(text) {
        text = text.trim()
        if (text === "" || busy) return
        const history = []
        for (let i = 0; i < messages.count; i++) {
            const m = messages.get(i)
            if (m.body !== "") history.push({ role: m.role, content: m.body })
        }
        history.push({ role: "user", content: text })
        messages.append({ role: "user", body: text })
        messages.append({ role: "assistant", body: "" })
        _pending = messages.count - 1
        busy = true
        ollama.exec(["curl", "-sN", "-X", "POST", endpoint, "-H", "Content-Type: application/json",
                     "-d", JSON.stringify({ model: model, messages: history, stream: true })])
    }
    function stop() { if (busy) ollama.running = false }
    function clear() { stop(); messages.clear(); messages.append({ role: "assistant", body: "Chat cleared." }) }

    ColumnLayout {
        anchors.fill: parent
        spacing: M3Tokens.dp(8)

        RowLayout {
            Layout.fillWidth: true
            M3Icon { name: "smart_toy"; size: M3Tokens.dp(20); color: M3Theme.primaryText }
            M3Text { Layout.fillWidth: true; text: "Assistant · " + root.model; type: "title" }
            M3IconButton { icon: root.busy ? "stop_circle" : "delete_sweep"; size: M3Tokens.dp(32)
                           onClicked: root.busy ? root.stop() : root.clear() }
        }

        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: M3Tokens.dp(6)
            model: messages
            onCountChanged: positionViewAtEnd()
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
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: M3Tokens.dp(6)
            M3TextField {
                id: input
                Layout.fillWidth: true; Layout.minimumWidth: 0
                placeholderText: root.busy ? "Thinking…" : "Message…"
                enabled: !root.busy
                onAccepted: { root.send(text); text = "" }
            }
            M3IconButton { icon: "send"; filled: true; size: M3Tokens.dp(44); enabled: !root.busy
                           onClicked: { root.send(input.text); input.text = "" } }
        }
    }
}
