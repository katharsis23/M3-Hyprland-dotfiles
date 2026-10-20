pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Inter-process bridge to the Python AI-companion backend.
//
// Quickshell runs its own QML engine in a separate process and cannot import the
// backend's PySide6 QObjects, so the backend is spawned as a child process that
// speaks line-delimited JSON over stdio:
//
//   request : {"id": <int>, "method": <str>, "params": {…}}
//   reply   : {"id": <int>, "ok": <bool>, "result"|"error": …}
//   event   : {"event": <str>, "data": <any>}          (server push, no id)
//
// This singleton owns that process, tracks pending request ids, and turns the
// backend's data into QML-friendly properties/signals. It is intentionally a
// *thin* transport: widgets bind to the properties below and call `request()`
// or the `send/…` convenience wrappers. See the AI sidebar section of the
// shell specification for the full UI contract.
Singleton {
    id: root

    // ---- Process configuration -------------------------------------------
    // Path to the backend checkout. Resolved from the `AI_GIRLFRIEND_HOME`
    // environment variable when set, otherwise a sensible default location;
    // `scripts/install.sh` records the real path on install.
    readonly property string backendRoot:
        (Quickshell.env("AI_GIRLFRIEND_HOME") || "").length > 0
            ? Quickshell.env("AI_GIRLFRIEND_HOME")
            : (Quickshell.env("HOME") + "/Projects/AI-girlfriend/AI_girlfriend_chat")

    // Prefer the project's Poetry virtualenv interpreter so PySide6/pydantic
    // are importable; fall back to plain `python3`.
    //
    // Resolution order:
    //   1. AI_GIRLFRIEND_PYTHON (exported from ~/.config/material-hyprland/
    //      ai-backend.env, which install.sh records and the profile sources),
    //   2. an in-project .venv (install.sh sets virtualenvs.in-project=true),
    //   3. plain python3 (works when deps are installed system-wide).
    readonly property string pythonExe: {
        const env = Quickshell.env("AI_GIRLFRIEND_PYTHON") || ""
        if (env.length > 0) return env
        return backendRoot + "/.venv/bin/python"
    }
    // If the env override / in-project venv is missing the Process simply
    // fails to spawn, which surfaces via `lastError` and the Retry affordance —
    // install.sh guarantees one of them is valid on a real install.

    // Run the bridge as a module so `from src.ai_girlfriend…` imports resolve.
    readonly property var command: [pythonExe, "-m", "src.ai_girlfriend.ui.ipc_server"]

    // ---- Connection / readiness state ------------------------------------
    property bool ready: false
    property bool starting: true
    property string lastError: ""
    property string version: ""

    // ---- Chat state (mirrors chat.header) --------------------------------
    property string characterName: ""
    property string characterId: ""
    property string greeting: ""
    property string initialExpression: "neutral"
    property string portraitEmoji: "🙂"
    property string expression: "neutral"          // current emotion id
    property string expressionUrl: ""               // portrait file:// url ("" => emoji)
    property bool busy: false
    property string chatId: ""

    // ---- Collections ------------------------------------------------------
    property var characterIds: []                    // [ "aria", … ]
    property var chats: []                          // [{id,preview,count,updated}, …]
    property var transcript: []                      // [{role,text}, …]
    property var themeIds: []
    property string themeId: ""

    // ---- LLM settings (mirrors backend settings.get) ---------------------
    // provider/url/model/apiKey/temperature/maxTokens/contextWindow + the list
    // of selectable providers and their suggested defaults. Widgets read this;
    // they never touch the backend process directly.
    // NB: no explicit `signal settingsChanged` — a QML `property var settings`
    // already generates an `onSettingsChanged` change signal. Widgets bind to
    // that; we just reassign `settings` to fire it.
    property var settings: ({
        provider: "ollama", model: "", url: "", apiKey: "", hasApiKey: false,
        temperature: 0.8, maxTokens: 512, contextWindow: 20, requestTimeout: 120.0,
        providers: ["ollama", "deepseek"], providerDefaults: {}
    })

    signal replyReceived(var payload)                // {role,text,expression,chatId}
    signal errorRaised(string message)
    signal chatLoaded(var transcript)
    signal charactersListed(var ids)
    signal themesListed(var ids)

    // ---- Transport --------------------------------------------------------
    property int _seq: 0
    property var _pending: ({})                      // id -> callback (for debugging)

    function _call(method, params, onDone) {
        const id = ++_seq
        if (!proc.running) {
            if (onDone) Qt.callLater(() => onDone(null, false, "backend not running"))
            return id
        }
        if (onDone) root._pending[id] = onDone
        const line = JSON.stringify({ id: id, method: method, params: params || {} })
        proc.write(line + "\n")
        return id
    }

    // Generic request; `onDone(result, ok, error)` is optional and id-tracked.
    function request(method, params, onDone) { return _call(method, params, onDone) }

    function _handleLine(line) {
        line = line.trim()
        if (line === "") return
        let msg
        try { msg = JSON.parse(line) } catch (e) { return }

        // Server-pushed event (no id).
        if (msg.event !== undefined) {
            if (msg.event === "ready") {
                root.ready = true; root.starting = false
                root.version = (msg.data && msg.data.version) || ""
                root.lastError = ""
                root._bootstrap()
            } else if (msg.event === "reply") {
                const d = msg.data || {}
                root.busy = false
                if (d.chatId !== undefined) root.chatId = d.chatId
                if (d.expression) root.expression = d.expression
                root._refreshExpressionUrl()
                root.replyReceived(d)
            } else if (msg.event === "error") {
                const d = msg.data || {}
                root.busy = false
                root.errorRaised(d.message || "backend error")
            }
            return
        }

        // Response to a request.
        if (msg.id !== undefined) {
            const cb = root._pending[msg.id]
            if (!msg.ok) { root.lastError = msg.error || "request failed" }
            if (cb) { delete root._pending[msg.id]; cb(msg.ok ? msg.result : null, msg.ok, msg.error) }
        }
    }

    // Pull the initial snapshot once the process is up.
    function _bootstrap() {
        _call("chat.header", {}, (r) => { if (r) root._applyHeader(r) })
        _call("characters.list", {}, (r) => {
            if (r) {
                root.characterIds = r.ids || []
                root.characterId = r.current || ""
                root.charactersListed(root.characterIds)
            }
        })
        refreshChats()
        refreshThemes()
        refreshSettings()
    }

    function _applyHeader(h) {
        root.characterName = h.characterName || ""
        root.characterId = h.characterId || root.characterId
        root.greeting = h.greeting || ""
        root.initialExpression = h.initialExpression || "neutral"
        root.portraitEmoji = h.portraitEmoji || "🙂"
        root.busy = !!h.busy
        root.chatId = h.chatId || ""
        root._refreshExpressionUrl()
    }

    function _refreshExpressionUrl() {
        const expr = root.expression || root.initialExpression || "neutral"
        _call("chat.expressionUrl", { expression: expr }, (r) => {
            root.expressionUrl = (r && r.url) || ""
        })
    }

    // ---- Chat actions -----------------------------------------------------
    function send(text) {
        if (text.trim() === "" || busy) return
        busy = true
        _call("chat.send", { text: text }, (r, ok, err) => {   // reply arrives as an event
            if (!ok) { root.busy = false; root.errorRaised(err || "send failed") }
        })
    }
    function resetChat() {
        _call("chat.reset", {}, () => {
            transcript = []
            expression = initialExpression
            _refreshExpressionUrl()
        })
    }
    function refreshChats() {
        _call("chat.list", { limit: 50 }, (r) => { if (r) root.chats = r.chats || [] })
    }
    function loadChat(id) {
        _call("chat.load", { chatId: id }, (r) => {
            if (!r) return
            root.transcript = r.transcript || []
            root.chatId = id
            root.chatLoaded(root.transcript)
        })
    }

    // ---- Character actions ------------------------------------------------
    function selectCharacter(id) {
        _call("characters.select", { id: id }, (r) => {
            if (!r || !r.selected) return
            root.characterId = r.selected
            if (r.header) root._applyHeader(r.header)
            root.transcript = []
        })
    }
    function characterInfo(id, onDone) { return _call("characters.info", { id: id }, onDone) }
    function newCharacterTemplate(onDone) { return _call("characters.template", {}, onDone) }
    function saveCharacter(form, onDone) {
        return _call("characters.save", form, (r, ok, err) => {
            if (r) {
                if (r.header) root._applyHeader(r.header)
                root.characterId = r.id || root.characterId
                _call("characters.list", {}, (l) => { if (l) root.characterIds = l.ids || [] })
            }
            if (onDone) onDone(r, ok, err)
        })
    }
    function deleteCharacter(id, onDone) {
        return _call("characters.delete", { id: id }, (r) => {
            if (r && r.deleted) {
                _call("characters.list", {}, (l) => {
                    if (l) { root.characterIds = l.ids || []; root.characterId = l.current || "" }
                })
            }
            if (onDone) onDone(r)
        })
    }

    // ---- Theme actions ----------------------------------------------------
    function refreshThemes() {
        _call("themes.list", {}, (r) => {
            if (r) {
                root.themeIds = r.ids || []
                root.themeId = r.current || ""
                root.themesListed(root.themeIds)
            }
        })
    }
    function themeInfo(id, onDone) { return _call("themes.info", { id: id }, onDone) }

    // ---- LLM settings -----------------------------------------------------
    function refreshSettings() {
        _call("settings.get", {}, (r) => {
            if (r) {
                root.settings = r
            }
        })
    }
    // Apply a partial settings update; `cb(settings, ok, error)`. A successful
    // apply rebuilds the backend pipeline, so the header/greeting may change.
    function saveSettings(patch, onDone) {
        return _call("settings.set", patch || {}, (r, ok, err) => {
            if (r) {
                root.settings = r
                // The provider/temperature change does not alter the character,
                // but refresh the header so any server-side state stays in sync.
                _call("chat.header", {}, (h) => { if (h) root._applyHeader(h) })
            }
            if (onDone) onDone(r, ok, err)
        })
    }

    // ---- Filesystem (image picker) ---------------------------------------
    function fsHome(onDone) { return _call("fs.home", {}, onDone) }
    function fsList(path, onDone) { return _call("fs.list", { path: path }, onDone) }
    function fsParent(path, onDone) { return _call("fs.parent", { path: path }, onDone) }

    property bool _restarting: false
    function restart() {
        ready = false; starting = true; lastError = ""; busy = false
        _pending = ({})
        if (proc.running) { _restarting = true; proc.running = false }   // respawn from onExited
        else proc.running = true
    }

    // ---- The child process ------------------------------------------------
    Process {
        id: proc
        command: root.command
        workingDirectory: root.backendRoot
        environment: ({ "PYTHONUNBUFFERED": "1", "PYTHONPATH": root.backendRoot })
        running: true

        stdout: SplitParser {
            onRead: (line) => root._handleLine(line)
        }
        onExited: (code) => {
            if (root._restarting) { root._restarting = false; proc.running = true; return }
            root.ready = false
            root.starting = false
            root.busy = false
            root.lastError = "backend exited (code " + code + ")"
            root.errorRaised(root.lastError)
        }
    }
}
