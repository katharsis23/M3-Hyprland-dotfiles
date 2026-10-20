import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"
import "../theme"
import "../core"

// Create / edit a character. `characterId === ""` means create (blank template),
// otherwise the form is prefilled via AiBridge.characterInfo and saved with
// `original_id` so the backend updates rather than duplicates.
Item {
    id: root
    property string characterId: ""
    signal saved(string id)
    signal cancelled()

    readonly property bool editing: characterId !== ""
    readonly property var baseExpressions: ["neutral", "happy", "thinking", "surprised", "sad", "angry"]

    // ---- form state -----------------------------------------------------
    property string originalId: ""
    property string initialExpression: "neutral"
    property var photoMap: ({})           // expression -> path (or backend-shaped value)
    property string formError: ""
    property bool loaded: false
    property bool saving: false
    property string pickingFor: ""        // expression being assigned in the file browser

    readonly property var expressionIds: {
        const out = baseExpressions.slice()
        const extra = Object.keys(photoMap).concat([initialExpression])
        for (const e of extra) if (e && out.indexOf(e) < 0) out.push(e)
        return out
    }

    // The backend may return a plain path or a wrapped value; read/write both.
    function _pathOf(v) {
        if (typeof v === "string") return v
        if (Array.isArray(v)) return typeof v[0] === "string" ? v[0] : ""
        if (v && typeof v === "object") return v.path || v.photo || v.file || ""
        return ""
    }
    function _withPath(old, p) {
        if (Array.isArray(old)) { const c = old.slice(); c[0] = p; return c }
        if (old && typeof old === "object") {
            const c = Object.assign({}, old)
            c[c.path !== undefined ? "path" : c.photo !== undefined ? "photo" : c.file !== undefined ? "file" : "path"] = p
            return c
        }
        return p
    }
    function _normalizeMap(m) {
        if (!m) return {}
        if (Array.isArray(m)) {                       // [{expression, path}, …]
            const o = {}
            for (const it of m) if (it && it.expression) o[it.expression] = it.path || it.photo || it.file || ""
            return o
        }
        return Object.assign({}, m)
    }
    function _num(text, integer) {
        const t = text.trim()
        if (t === "") return null                     // empty => backend default
        const n = integer ? parseInt(t) : parseFloat(t)
        return isNaN(n) ? null : n
    }

    function _fill(f) {
        nameField.text = f.name || ""
        personalityArea.text = f.personality || ""
        greetingField.text = f.greeting_message || ""
        initialExpression = f.initial_expression || "neutral"
        tempField.text = (f.temperature === undefined || f.temperature === null) ? "" : String(f.temperature)
        tokensField.text = (f.max_tokens === undefined || f.max_tokens === null) ? "" : String(f.max_tokens)
        photoMap = _normalizeMap(f.photo_emoji_map !== undefined ? f.photo_emoji_map : f.photos)
        loaded = true
    }

    Component.onCompleted: {
        if (editing) {
            originalId = characterId
            AiBridge.characterInfo(characterId, (r, ok, err) => {
                if (r) root._fill(r)
                else { root.formError = err || "Could not load character"; root.loaded = true }
            })
        } else {
            AiBridge.newCharacterTemplate((r) => { root._fill(r || {}) })
        }
    }

    function save() {
        formError = ""
        saving = true
        const form = {
            name: nameField.text.trim(),
            personality: personalityArea.text,
            greeting_message: greetingField.text,
            initial_expression: initialExpression,
            temperature: _num(tempField.text, false),
            max_tokens: _num(tokensField.text, true),
            photo_emoji_map: photoMap
        }
        if (originalId !== "") form.original_id = originalId
        AiBridge.saveCharacter(form, (r, ok, err) => {
            root.saving = false
            if (r) root.saved(r.id || "")
            else root.formError = err || "Could not save character"
        })
    }

    // ---- form ------------------------------------------------------------
    M3Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: actions.top
                  bottomMargin: M3Tokens.spaceSm }
        contentHeight: form.implicitHeight
        visible: !browser.visible

        ColumnLayout {
            id: form
            width: flick.width - M3Tokens.dp(6)
            spacing: M3Tokens.spaceSm

            M3Text { text: "Name"; type: "label"; muted: true }
            M3TextField { id: nameField; Layout.fillWidth: true; placeholderText: "Required" }

            M3Text { text: "Personality"; type: "label"; muted: true }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(M3Tokens.dp(110), personalityArea.contentHeight + M3Tokens.dp(24))
                radius: M3Tokens.cornerRadiusLg
                color: M3Theme.surfaceContainerHighest
                border.width: personalityArea.activeFocus ? 2 : 1
                border.color: personalityArea.activeFocus ? M3Theme.primary : M3Theme.outlineVariant
                TextArea {
                    id: personalityArea
                    anchors { fill: parent; margins: M3Tokens.dp(4) }
                    leftPadding: M3Tokens.dp(14); rightPadding: M3Tokens.dp(14)
                    topPadding: M3Tokens.dp(10); bottomPadding: M3Tokens.dp(10)
                    wrapMode: TextEdit.Wrap
                    color: M3Theme.fg
                    placeholderTextColor: M3Theme.fgMuted
                    placeholderText: "How does this character speak and behave?"
                    selectionColor: M3Theme.primary; selectedTextColor: M3Theme.primaryFg
                    font.family: Typography.family; font.pixelSize: Typography.bodyLarge
                    selectByMouse: true
                    background: null
                }
            }

            M3Text { text: "Greeting message"; type: "label"; muted: true }
            M3TextField { id: greetingField; Layout.fillWidth: true; placeholderText: "First thing they say" }

            M3Text { text: "Initial expression"; type: "label"; muted: true }
            Repeater {
                model: Math.ceil(root.expressionIds.length / 3)
                delegate: M3Segmented {
                    required property int index
                    Layout.fillWidth: true
                    current: root.initialExpression
                    options: root.expressionIds.slice(index * 3, index * 3 + 3)
                                 .map(e => ({ value: e, label: e }))
                    onPicked: (v) => root.initialExpression = v
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: M3Tokens.spaceSm
                ColumnLayout {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: M3Tokens.spaceXs
                    M3Text { text: "Temperature"; type: "label"; muted: true }
                    M3TextField {
                        id: tempField; Layout.fillWidth: true; placeholderText: "default"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        validator: DoubleValidator { bottom: 0; top: 2; decimals: 2; notation: DoubleValidator.StandardNotation }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: M3Tokens.spaceXs
                    M3Text { text: "Max tokens"; type: "label"; muted: true }
                    M3TextField {
                        id: tokensField; Layout.fillWidth: true; placeholderText: "default"
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 1 }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: M3Tokens.spaceSm
                M3Text { Layout.fillWidth: true; text: "Portrait images"; type: "label"; muted: true }
            }
            Repeater {
                model: Object.keys(root.photoMap)
                delegate: Rectangle {
                    id: mapRow
                    required property string modelData
                    readonly property string path: root._pathOf(root.photoMap[modelData])
                    Layout.fillWidth: true
                    implicitHeight: M3Tokens.dp(56)
                    radius: M3Tokens.cornerRadiusMd
                    color: M3Theme.surfaceContainerHighest
                    RowLayout {
                        anchors { fill: parent; leftMargin: M3Tokens.dp(10); rightMargin: M3Tokens.dp(6) }
                        spacing: M3Tokens.dp(10)
                        Portrait { size: M3Tokens.dp(40); source: mapRow.path; emoji: "🖼" }
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 0
                            M3Text { Layout.fillWidth: true; text: mapRow.modelData; type: "label" }
                            M3Text { Layout.fillWidth: true; text: mapRow.path; type: "caption"; muted: true
                                     elide: Text.ElideLeft }
                        }
                        M3IconButton {
                            icon: "swap_horiz"; size: M3Tokens.dp(32); tooltip: "Replace"
                            onClicked: { root.pickingFor = mapRow.modelData; browser.visible = true }
                        }
                        M3IconButton {
                            icon: "close"; size: M3Tokens.dp(32); tooltip: "Remove"
                            onClicked: { const m = Object.assign({}, root.photoMap); delete m[mapRow.modelData]; root.photoMap = m }
                        }
                    }
                }
            }
            M3Text {
                visible: Object.keys(root.photoMap).length === 0
                text: "No portraits — the emoji avatar is used"; type: "caption"; muted: true
            }
            // Add a portrait for an expression that has none yet.
            Flow {
                Layout.fillWidth: true
                spacing: M3Tokens.spaceXs
                Repeater {
                    model: root.expressionIds.filter(e => root.photoMap[e] === undefined)
                    delegate: M3Button {
                        required property string modelData
                        compact: true; icon: "add_photo_alternate"; text: modelData
                        onClicked: { root.pickingFor = modelData; browser.visible = true }
                    }
                }
            }
            Item { Layout.preferredHeight: M3Tokens.spaceSm }
        }
    }

    FileBrowser {
        id: browser
        anchors.fill: parent
        visible: false
        onCancelled: visible = false
        onPicked: (path) => {
            const m = Object.assign({}, root.photoMap)
            m[root.pickingFor] = root._withPath(m[root.pickingFor], path)
            root.photoMap = m
            visible = false
        }
    }

    // ---- footer ----------------------------------------------------------
    ColumnLayout {
        id: actions
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: M3Tokens.spaceSm
        visible: !browser.visible
        M3Text {
            Layout.fillWidth: true
            visible: root.formError !== ""
            text: root.formError; color: M3Theme.error; wrapMode: Text.Wrap; elide: Text.ElideNone
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: M3Tokens.spaceSm
            M3Button { Layout.fillWidth: true; text: "Cancel"; variant: "outlined"; onClicked: root.cancelled() }
            M3Button {
                Layout.fillWidth: true
                text: root.saving ? "Saving…" : "Save"; icon: "check"; variant: "filled"
                enabled: root.loaded && !root.saving && nameField.text.trim() !== ""
                onClicked: root.save()
            }
        }
    }
}
