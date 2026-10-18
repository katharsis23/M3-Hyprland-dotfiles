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

    // ---- Per-workspace windows + app icon resolution ---------------------
    // Snapshot of `hyprctl clients -j` (parsed), refreshed on Hyprland events.
    // Gives us {class, title, workspace:{id}} for every window without relying
    // on the toplevel mapping (some classes only appear here reliably).
    property var clients: []
    readonly property int clientEpoch: _clientEpoch
    property int _clientEpoch: 0

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(this.text)
                    root.clients = arr
                    root._clientEpoch++
                } catch (e) { /* keep previous */ }
            }
        }
        function refresh() { running = true }
    }

    // Windows sitting on a given numeric workspace id.
    function clientsForWorkspace(id) {
        const out = []
        for (let i = 0; i < clients.length; i++) {
            const c = clients[i]
            if (c && c.workspace && c.workspace.id === id) out.push(c)
        }
        return out
    }

    // The app class shown for a workspace: prefer the focused/last window's
    // class, otherwise the first window on it.
    function workspaceClass(id) {
        const list = clientsForWorkspace(id)
        if (list.length === 0) return ""
        // The last window reported by hyprctl on that ws is a good pick; fall
        // back to the first if lastwindow address is unknown.
        return list[list.length - 1].class || ""
    }

    // Small class -> icon-theme name map for common apps whose window class
    // does not equal a usable icon name.
    readonly property var iconMap: ({
        "com.microsoft.VSCode": "vscode",
        "code": "vscode",
        "code-insiders": "vscode",
        "nemo": "folder",
        "kitty": "kitty",
        "org.gnome.Nautilus": "folder",
        "firefox": "firefox",
        "firefox-esr": "firefox",
        "chromium": "chromium",
        "google-chrome": "google-chrome",
        "brave-browser": "brave-browser",
        "discord": "discord",
        "Spotify": "spotify",
        "TelegramDesktop": "telegram",
        "org.telegram.desktop": "telegram",
        "thunderbird": "thunderbird",
        "obsidian": "obsidian",
        "steam": "steam",
        "mpv": "mpv",
        "vlc": "vlc",
        "org.gimp.GIMP": "gimp",
        "org.kde.dolphin": "folder",
        "Alacritty": "utilities-terminal",
        "foot": "utilities-terminal"
    })

    // Terminal emulators. The workspace bar renders a Nerd Font glyph for these
    // classes instead of a (frequently missing) icon-theme pixmap.
    readonly property var terminalClasses: ({
        "kitty": true,
        "Alacritty": true,
        "alacritty": true,
        "foot": true,
        "footclient": true,
        "org.wezfurlong.wezterm": true,
        "com.mitchellh.ghostty": true,
        "ghostty": true,
        "konsole": true,
        "org.gnome.Terminal": true,
        "XTerm": true
    })

    function isTerminalClass(cls) {
        if (!cls) return false
        return terminalClasses[cls] === true
    }

    // Resolve a window class to an absolute icon path (or "" if none).
    function iconForClass(cls) {
        if (!cls || cls === "") return ""
        const name = iconMap[cls] || cls
        // Try the mapped/raw name, then a lowercased variant, then a desktop
        // file lookup is handled by the caller (AppIcon) as a last resort.
        let p = Quickshell.iconPath(name, true)
        if (p === "" || p === undefined) p = Quickshell.iconPath(name.toLowerCase(), true)
        if (p === "" || p === undefined) p = Quickshell.iconPath("application-x-executable", true)
        return p || ""
    }
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
                       || event.name === "movewindow" || event.name === "workspace"
                       || event.name === "moveworkspace" || event.name === "windowtitle") {
                Hyprland.refreshWorkspaces()
                clientsProc.refresh()
            } else if (event.name === "activewindow" || event.name === "activewindowv2") {
                Hyprland.refreshToplevels()
            }
        }
    }

    // Keep the client list fresh on a slow tick (covers class changes, etc.).
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: clientsProc.refresh()
    }

    Component.onCompleted: { reloadBinds(); clientsProc.refresh() }

    // --- Dispatch helpers --------------------------------------------------
    function dispatch(request) { Hyprland.dispatch(request) }
    function focusWorkspace(id) { Hyprland.dispatch("workspace " + id) }
    function moveToWorkspace(id) { Hyprland.dispatch("movetoworkspacesilent " + id) }
    function exec(cmd) { Hyprland.dispatch("exec " + cmd) }
}


