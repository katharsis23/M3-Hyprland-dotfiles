pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Backs the in-shell wallpaper picker (windows/WallpaperPicker.qml).
//
// Lists every image found in the usual wallpaper directories (delegated to the
// bundled `wallpaper-scan.sh`, which in turn calls hypr/scripts/
// wallpaper_manager.py), tracks the active wallpaper, and applies a new one —
// which also regenerates the Material 3 palette via matugen.
Singleton {
    id: root

    // Absolute paths of every discovered wallpaper (newline separated in
    // `_rawList`; parsed into `_images` for the grid).
    property var images: _images
    property var _images: []
    property string current: ""
    property bool loading: false
    // Whether the displayed wallpaper is blurred (persisted by the manager in
    // ~/.cache/material-hyprland/wallpaper-blur).
    property bool blur: false

    // "" until the scan has run at least once (drives the "no wallpapers" hint).
    property bool scanned: false

    readonly property string helper: Quickshell.shellPath("scripts/wallpaper-scan.sh") || ""

    // ---- discovery -------------------------------------------------------
    Process {
        id: listProc
        command: ["bash", root.helper, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const out = []
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].trim()
                    if (p !== "") out.push(p)
                }
                root._images = out
                root.loading = false
                root.scanned = true
            }
        }
    }
    Process {
        id: currentProc
        command: ["bash", root.helper, "current"]
        stdout: StdioCollector {
            onStreamFinished: root.current = this.text.trim()
        }
    }
    // Reads the persisted blur state ("on"/"off") so the switch reflects reality.
    Process {
        id: blurQueryProc
        command: ["bash", root.helper, "blur"]
        stdout: StdioCollector {
            onStreamFinished: root.blur = this.text.trim() === "on"
        }
    }

    function refresh() {
        if (listProc.running) return
        loading = true
        listProc.running = true
        currentProc.running = true
        blurQueryProc.running = true
    }

    // ---- apply -----------------------------------------------------------
    property string lastError: ""
    Process {
        id: setProc
        stdout: StdioCollector { onStreamFinished: {} }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                root.lastError = msg
                if (msg !== "") console.warn("WallpaperService: " + msg)
            }
        }
    }

    // Apply a wallpaper and remember it as current. The manager also rewrites
    // the matugen palette, so the whole terminal/GTK theme follows.
    function setWallpaper(path) {
        if (!path || path === "") return
        lastError = ""
        current = path
        setProc.exec(["bash", helper, "set", path])
        // Re-scan shortly after so the ordering reflects the new mtime/sort.
        reloadTimer.restart()
    }

    // ---- blur ------------------------------------------------------------
    // Turns wallpaper blur on/off. The manager persists the choice and
    // re-applies the current wallpaper so the change is visible immediately.
    Process {
        id: blurSetProc
        stdout: StdioCollector {
            onStreamFinished: root.blur = this.text.trim() === "on"
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg !== "") { root.lastError = msg; console.warn("WallpaperService: " + msg) }
            }
        }
    }
    function setBlur(enabled) {
        lastError = ""
        blur = enabled
        blurSetProc.exec(["bash", helper, "blur", enabled ? "on" : "off"])
        reloadTimer.restart()
    }

    // A lightweight "absolute file" URL usable as an Image source.
    function fileUrl(path) { return path ? "file://" + path : "" }

    // File name without its directory, for captions.
    function baseName(path) {
        if (!path) return ""
        const parts = path.split("/")
        return parts.length ? parts[parts.length - 1] : path
    }

    Timer { id: reloadTimer; interval: 1400; onTriggered: root.refresh() }

    Component.onCompleted: refresh()
}

