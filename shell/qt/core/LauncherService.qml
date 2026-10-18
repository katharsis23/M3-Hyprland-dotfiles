pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "."

// Drives the custom in-shell application launcher.
//
// Scans XDG .desktop files once at start (and on demand), keeps the parsed
// entries in a ListModel, and exposes filtering + activation. The QML popup
// (windows/Launcher.qml) just binds to `results` / `query` and calls launch().
//
// Parsing is delegated to a tiny bash/grep pipeline so we don't need a parser
// dependency; output is NUL-separated records "name\tgeneric\ticon\texeckey".
Singleton {
    id: root

    property bool open: false
    property string query: ""

    ListModel { id: allApps }

    // Map a query to the model index + a highlight substring for the view.
    readonly property var results: _filtered
    property var _filtered: []

    // Scan XDG data dirs for .desktop files via the bundled helper script.
    // (Keeping the parsing in bash avoids fragile JS-string escaping and lets
    //  users tweak the scanner without touching QML.)
    readonly property string scanHelper:
        (Quickshell.shellPath("scripts/launch-scan.sh") || "")

    Process {
        id: scanProc
        // Prints one record per line: NAME|GENERIC|ICON|EXEC
        command: ["bash", root.scanHelper]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    function refresh() { if (!scanProc.running) scanProc.running = true }

    function _parse(text) {
        allApps.clear()
        const lines = text.split("\n")
        const seen = ({})
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line === "") continue
            const parts = line.split("|")
            if (parts.length < 4) continue
            const name = parts[0]
            const key = name.toLowerCase()
            if (seen[key]) continue        // dedupe by display name
            seen[key] = true
            allApps.append({
                name: name,
                generic: parts[1],
                icon: parts[2],
                exec: parts[3]
            })
        }
        _recompute()
    }

    function _recompute() {
        const q = (query || "").trim().toLowerCase()
        const out = []
        for (let i = 0; i < allApps.count; i++) {
            const a = allApps.get(i)
            const hay = (a.name + " " + a.generic).toLowerCase()
            if (q === "" || hay.indexOf(q) >= 0) {
                out.push({ index: i, name: a.name, generic: a.generic, icon: a.icon, exec: a.exec })
            }
            if (out.length >= 60) break
        }
        _filtered = out
    }

    onQueryChanged: _recompute()

    function show() {
        scanProc.running = true
        // Open on the focused monitor.
        if (Hyprland.focusedMonitor)
            ConfigProvider.overlayScreen = Hyprland.focusedMonitor.name
        open = true
        query = ""
    }
    function hide() { open = false; query = "" }
    function toggle() { open ? hide() : show() }

    function launch(item) {
        if (!item || !item.exec) return
        hide()
        // Strip desktop-file exec field placeholders and run detached.
        Quickshell.execDetached(["bash", "-c", item.exec])
    }

    Component.onCompleted: refresh()
}
