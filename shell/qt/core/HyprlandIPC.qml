pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Live Hyprland state: workspaces, focused window, keybinds, title, submap.
//
// Everything here is reactive. Components bind to these properties and update
// automatically as Hyprland emits events over its IPC socket.
Singleton {
    id: root

    // The workspace currently focused on the focused monitor.
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property int activeWorkspaceId:
        focusedWorkspace ? focusedWorkspace.id : 1

    readonly property string activeWorkspaceName:
        focusedWorkspace ? focusedWorkspace.name : "1"

    // All existing workspaces sorted by id (includes named/negative ids).
    readonly property var workspaceList: {
        const out = []
        const ws = Hyprland.workspaces
        for (let i = 0; i < ws.length; i++) out.push(ws.values[i])
        return out
    }

    // Numeric workspaces only, ids ascending. Used by the workspace indicator.
    readonly property var numericWorkspaces: workspaceList.filter(w => w.id > 0)

    // The focused toplevel (window) title / class.
    readonly property string activeTitle:
        Hyprland.activeToplevel ? (Hyprland.activeToplevel.title || "") : ""
    readonly property string activeClass: {
        const t = Hyprland.activeToplevel
        if (!t || !t.lastIpcObject) return ""
        // `class` is a reserved JS keyword; access via brackets.
        return t.lastIpcObject["class"] || ""
    }
    // Submap (e.g. "resize") — empty when in the default submap.
    readonly property string submap: _submap
    property string _submap: ""

    // Keybinds loaded from `hyprctl binds -j`.
    readonly property var binds: _binds
    property var _binds: []

    // Re-fetch workspace data periodically for values that have no dedicated
    // event binding (rare; keeps the bar accurate across manual hyprctl calls).
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: Hyprland.refreshWorkspaces()
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(this.text)
                    root._binds = arr.map(b => ({
                        modmask: b.modmask,
                        key: b.key,
                        keycode: b.keycode,
                        submap: b.submap,
                        description: b.description || "",
                        dispatcher: b.dispatcher,
                        arg: b.arg || ""
                    }))
                } catch (e) {
                    root._binds = []
                }
            }
        }
    }

    function reloadBinds() { bindsProc.running = true }

    // Listen to raw events for submap changes and window focus refresh.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap") {
                root._submap = event.data || ""
            } else if (event.name === "openwindow" || event.name === "closewindow"
                       || event.name === "movewindow" || event.name === "workspace") {
                Hyprland.refreshWorkspaces()
            } else if (event.name === "activewindow" || event.name === "activewindowv2") {
                Hyprland.refreshToplevels()
            }
        }
    }

    Component.onCompleted: reloadBinds()

    // --- Dispatch helpers --------------------------------------------------
    function dispatch(request) { Hyprland.dispatch(request) }
    function focusWorkspace(id) { Hyprland.dispatch("workspace " + id) }
    function moveToWorkspace(id) { Hyprland.dispatch("movetoworkspacesilent " + id) }
    function exec(cmd) { Hyprland.dispatch("exec " + cmd) }
}


