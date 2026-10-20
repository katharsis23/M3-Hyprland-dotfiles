import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../core"

// Assistant settings: LLM provider/model/generation knobs, backend theme
// preview, active character and diagnostics. Everything under "Model &
// provider" is driven by the backend `settings.get`/`settings.set` API and is
// persisted to the backend's config.json; shell appearance stays in
// ConfigProvider/matugen.
M3Flickable {
    id: root
    signal openCharacters()

    contentHeight: col.implicitHeight

    property string previewId: AiBridge.themeId
    property var previewInfo: ({})

    // Local, editable copy of the backend settings. We stage edits here and
    // only push to the backend on field commit so a partially typed value never
    // triggers a provider rebuild on every keystroke.
    property string provider: AiBridge.settings.provider || "ollama"
    property string model: AiBridge.settings.model || ""
    property string url: AiBridge.settings.url || ""
    property string apiKey: AiBridge.settings.apiKey || ""
    property real temperature: AiBridge.settings.temperature !== undefined ? AiBridge.settings.temperature : 0.8
    property int maxTokens: AiBridge.settings.maxTokens !== undefined ? AiBridge.settings.maxTokens : 512
    property int contextWindow: AiBridge.settings.contextWindow !== undefined ? AiBridge.settings.contextWindow : 20
    property string status: ""              // transient feedback under the section
    property bool saving: false
    property bool _loaded: false

    function _loadFromBridge() {
        const s = AiBridge.settings
        provider = s.provider || "ollama"
        model = s.model || ""
        url = s.url || ""
        apiKey = s.apiKey || ""
        temperature = s.temperature !== undefined ? s.temperature : 0.8
        maxTokens = s.maxTokens !== undefined ? s.maxTokens : 512
        contextWindow = s.contextWindow !== undefined ? s.contextWindow : 20
        _loaded = true
    }
    Connections {
        target: AiBridge
        function onSettingsChanged() { root._loadFromBridge() }
    }
    Component.onCompleted: { if (AiBridge.ready) AiBridge.refreshSettings(); _loadFromBridge() }

    function _save(patch) {
        if (!AiBridge.ready) { status = "Backend not connected"; return }
        saving = true; status = ""
        AiBridge.saveSettings(patch, (r, ok, err) => {
            saving = false
            if (!ok) { status = err || "Could not save settings" }
            else { status = "Saved"; statusTimer.restart() }
        })
    }
    Timer { id: statusTimer; interval: 2500; onTriggered: root.status = "" }

    // Provider switch also seeds that provider's suggested url/model in the UI
    // (the backend applies the same defaults unless we send explicit values).
    function _chooseProvider(id) {
        provider = id
        const defs = AiBridge.settings.providerDefaults || {}
        const d = defs[id] || {}
        if (d.model) model = d.model
        if (d.url) url = d.url
        _save({ provider: id })
    }

    function _preview(id) {
        AiBridge.themeInfo(id, (r) => { if (r && id === root.previewId) root.previewInfo = r })
    }
    onPreviewIdChanged: if (previewId !== "") _preview(previewId)

    ColumnLayout {
        id: col
        width: root.width - M3Tokens.dp(6)
        spacing: M3Tokens.spaceMd

        // ---- Model & provider ----------------------------------------------
        M3Text { text: "Model & provider"; type: "title" }
        M3Card {
            Layout.fillWidth: true
            implicitHeight: modelCol.implicitHeight + padding * 2
            ColumnLayout {
                id: modelCol
                width: parent.width
                spacing: M3Tokens.spaceSm

                M3Text { text: "Provider"; type: "label"; muted: true }
                M3Segmented {
                    Layout.fillWidth: true
                    current: root.provider
                    options: (AiBridge.settings.providers || ["ollama"]).map(function(p) {
                        return {
                            value: p,
                            label: p.charAt(0).toUpperCase() + p.slice(1),
                            icon: p === "ollama" ? "memory" : "cloud"
                        }
                    })
                    onPicked: function(id) { root._chooseProvider(id) }
                }

                M3Text { text: "Endpoint URL"; type: "label"; muted: true; Layout.topMargin: M3Tokens.dp(4) }
                M3TextField {
                    Layout.fillWidth: true
                    icon: "link"
                    text: root.url
                    placeholderText: root.provider === "deepseek"
                        ? "https://api.deepseek.com/v1" : "http://localhost:11434"
                    onEditingFinished: if (text.trim() !== "" && text.trim() !== root.url) { root.url = text.trim(); root._save({ url: root.url }) }
                }

                M3Text { text: "Model"; type: "label"; muted: true; Layout.topMargin: M3Tokens.dp(4) }
                M3TextField {
                    Layout.fillWidth: true
                    icon: "tune"
                    text: root.model
                    placeholderText: root.provider === "deepseek" ? "deepseek-chat" : "llama3"
                    onEditingFinished: if (text.trim() !== "" && text.trim() !== root.model) { root.model = text.trim(); root._save({ model: root.model }) }
                }

                M3Text {
                    text: "API key"; type: "label"; muted: true
                    visible: root.provider === "deepseek"
                    Layout.topMargin: M3Tokens.dp(4)
                }
                M3TextField {
                    Layout.fillWidth: true
                    visible: root.provider === "deepseek"
                    icon: "key"
                    echoMode: TextInput.Password
                    text: root.apiKey
                    placeholderText: AiBridge.settings.hasApiKey ? "•••••••• (saved)" : "sk-…"
                    onEditingFinished: if (text !== root.apiKey) { root.apiKey = text; root._save({ apiKey: root.apiKey }) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: M3Tokens.dp(6)
                    M3Text { text: "Temperature"; Layout.fillWidth: true }
                    M3Text { text: root.temperature.toFixed(2); muted: true }
                }
                M3Slider {
                    Layout.fillWidth: true
                    from: 0.0; to: 2.0; stepSize: 0.05
                    value: root.temperature
                    onMoved: root.temperature = Math.round(value * 100) / 100
                    onPressedChanged: if (!pressed) root._save({ temperature: root.temperature })
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: M3Tokens.dp(6)
                    spacing: M3Tokens.spaceSm
                    ColumnLayout {
                        Layout.fillWidth: true
                        M3Text { text: "Max tokens"; type: "label"; muted: true }
                        M3TextField {
                            Layout.fillWidth: true
                            icon: "short_text"
                            text: "" + root.maxTokens
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 1; top: 100000 }
                            onEditingFinished: {
                                const v = parseInt(text)
                                if (!isNaN(v) && v !== root.maxTokens) { root.maxTokens = v; root._save({ maxTokens: v }) }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        M3Text { text: "Context window"; type: "label"; muted: true }
                        M3TextField {
                            Layout.fillWidth: true
                            icon: "forum"
                            text: "" + root.contextWindow
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 1; top: 1000 }
                            onEditingFinished: {
                                const v = parseInt(text)
                                if (!isNaN(v) && v !== root.contextWindow) { root.contextWindow = v; root._save({ contextWindow: v }) }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.status !== "" || root.saving
                    spacing: M3Tokens.dp(6)
                    M3Icon {
                        name: root.saving ? "hourglass_top" : (root.status === "Saved" ? "check_circle" : "error")
                        size: M3Tokens.dp(16)
                        color: (root.saving || root.status === "Saved") ? M3Theme.primaryText : M3Theme.error
                    }
                    M3Text {
                        Layout.fillWidth: true; Layout.minimumWidth: 0
                        text: root.saving ? "Applying…" : root.status
                        type: "caption"; wrapMode: Text.Wrap; elide: Text.ElideNone
                        color: root.status === "Saved" ? M3Theme.primaryText : M3Theme.fgMuted
                    }
                }
            }
        }

        // ---- Appearance ----------------------------------------------------
        M3Text { text: "Appearance"; type: "title" }
        M3Card {
            Layout.fillWidth: true
            implicitHeight: appearance.implicitHeight + padding * 2
            ColumnLayout {
                id: appearance
                width: parent.width
                spacing: M3Tokens.spaceSm
                Flow {
                    Layout.fillWidth: true
                    spacing: M3Tokens.spaceXs
                    Repeater {
                        model: AiBridge.themeIds
                        delegate: M3Button {
                            required property string modelData
                            compact: true
                            text: modelData
                            toggled: modelData === AiBridge.themeId
                            onClicked: {
                                root.previewId = modelData
                                AiBridge.request("themes.select", { id: modelData }, () => AiBridge.refreshThemes())
                            }
                        }
                    }
                }
                M3Text {
                    visible: AiBridge.themeIds.length === 0
                    text: AiBridge.ready ? "No themes available" : "Backend not connected"
                    type: "caption"; muted: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.previewInfo.primary !== undefined
                    spacing: M3Tokens.spaceSm
                    Repeater {
                        model: ["primary", "secondary", "tertiary", "background", "surface", "onSurface"]
                        delegate: ColumnLayout {
                            required property string modelData
                            Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: M3Tokens.dp(2)
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: M3Tokens.dp(28)
                                radius: M3Tokens.cornerRadiusSm
                                color: root.previewInfo[modelData] || "transparent"
                                border.width: 1; border.color: M3Theme.outlineVariant
                            }
                            M3Text { Layout.fillWidth: true; text: modelData; type: "caption"; muted: true
                                     horizontalAlignment: Text.AlignHCenter }
                        }
                    }
                }
            }
        }

        // ---- Assistant -----------------------------------------------------
        M3Text { text: "Assistant"; type: "title" }
        M3Tile {
            Layout.fillWidth: true
            icon: "face"
            label: AiBridge.characterName !== "" ? AiBridge.characterName : "No character"
            detail: "Active character — tap to change"
            onTapped: root.openCharacters()
        }

        // ---- Diagnostics ---------------------------------------------------
        M3Text { text: "Diagnostics"; type: "title" }
        M3Card {
            Layout.fillWidth: true
            implicitHeight: diag.implicitHeight + padding * 2
            ColumnLayout {
                id: diag
                width: parent.width
                spacing: M3Tokens.spaceSm
                RowLayout {
                    Layout.fillWidth: true
                    M3Text { text: "Backend"; Layout.fillWidth: true }
                    M3Text {
                        text: AiBridge.ready ? "ready" : AiBridge.starting ? "starting…" : "offline"
                        color: AiBridge.ready ? M3Theme.primaryText : AiBridge.starting ? M3Theme.fgMuted : M3Theme.error
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    M3Text { text: "Provider"; Layout.fillWidth: true }
                    M3Text { text: AiBridge.settings.provider || "—"; muted: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    M3Text { text: "Protocol version"; Layout.fillWidth: true }
                    M3Text { text: AiBridge.version !== "" ? AiBridge.version : "—"; muted: true }
                }
                M3Text {
                    Layout.fillWidth: true
                    visible: AiBridge.lastError !== ""
                    text: AiBridge.lastError; color: M3Theme.error
                    wrapMode: Text.Wrap; elide: Text.ElideNone; type: "caption"
                }
                M3Button {
                    Layout.fillWidth: true
                    text: "Restart bridge"; icon: "restart_alt"; variant: "tonal"
                    onClicked: AiBridge.restart()
                }
            }
        }
        Item { Layout.preferredHeight: M3Tokens.spaceSm }
    }
}
