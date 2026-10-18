import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components"
import "../theme"
import "../core"

// Live Hyprland workspaces 1..10.
//  - empty    -> ring with the workspace number
//  - occupied -> shows the app icon of a window living on it
//  - active   -> Material "pill" (white rounded cell, Nerd-Font app glyph)
//  - kitty    -> terminals always show the Nerd Font terminal glyph (U+F120),
//                so an open terminal is readable even without an icon theme
// `compact` (thin/vertical bars) shrinks the cell but keeps the app icon so you
// can see what runs where at a glance.
// Mouse wheel switches workspace; click focuses it.
Item {
    id: root
    property bool vertical: false
    property bool compact: false
    property int workspaceCount: 10

    readonly property int cell: M3Tokens.dp(compact ? 22 : 30)
    readonly property int gap: M3Tokens.dp(compact ? 3 : 5)
    // Nerd Font glyph shown for terminals (no good icon-theme pixmap needed).
    readonly property string terminalGlyph: "\uf120"   // nf-fa-terminal
    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    // Touch clientEpoch so these re-evaluate when windows move/open/close.
    function wsById(id) {
        const e = HyprlandIPC.clientEpoch
        const list = HyprlandIPC.numericWorkspaces
        for (let i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
        return null
    }
    function occupied(id) {
        const e = HyprlandIPC.clientEpoch
        return HyprlandIPC.clientsForWorkspace(id).length > 0
    }
    function clientsFor(id) {
        const e = HyprlandIPC.clientEpoch
        return HyprlandIPC.clientsForWorkspace(id)
    }
    function classFor(id) {
        const e = HyprlandIPC.clientEpoch
        return HyprlandIPC.workspaceClass(id)
    }
    // True when a terminal (kitty/foot/alacritty/...) lives on the workspace.
    function hasTerminal(id) {
        const list = clientsFor(id)
        for (let i = 0; i < list.length; i++) {
            if (HyprlandIPC.isTerminalClass(list[i].class || "")) return true
        }
        return false
    }

    Grid {
        id: grid
        columns: root.vertical ? 1 : root.workspaceCount
        spacing: root.gap
        Repeater {
            model: root.workspaceCount
            delegate: Rectangle {
                id: pill
                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: root.wsById(wsId)
                readonly property bool active: HyprlandIPC.activeWorkspaceId === wsId
                readonly property bool occupied: root.occupied(wsId)
                readonly property bool urgent: ws !== null && ws.urgent
                readonly property string appClass: root.classFor(wsId)
                readonly property bool terminal: root.hasTerminal(wsId)

                width: root.cell
                height: root.cell
                // Active workspace morphs into a rounded pill, like Material 3.
                radius: active ? height / 2 : M3Tokens.cornerRadiusSm
                color: active ? M3Theme.primary
                     : urgent ? M3Theme.error
                     : (hover.hovered ? M3Theme.surfaceContainerHighest
                        : (occupied ? M3Theme.surfaceContainerHigh : "transparent"))
                border.width: (!active && !urgent && !occupied) ? 1 : 0
                border.color: M3Theme.outlineVariant
                Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }
                Behavior on radius { NumberAnimation { duration: M3Tokens.durationShort } }

                // Nerd Font terminal glyph for terminal windows (kitty etc.).
                M3Text {
                    anchors.centerIn: parent
                    visible: pill.occupied && pill.terminal
                    text: root.terminalGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(pill.width * 0.55)
                    elide: Text.ElideNone
                    color: pill.active ? M3Theme.primaryFg
                         : pill.urgent ? M3Theme.errorFg : M3Theme.fg
                }
                // App icon when the workspace has a (non-terminal) window,
                // otherwise its number.
                AppIcon {
                    anchors.centerIn: parent
                    visible: pill.occupied && !pill.terminal
                    appClass: pill.appClass
                    size: Math.round(pill.width * 0.62)
                    tint: pill.active ? M3Theme.primaryFg : M3Theme.fg
                }
                M3Text {
                    anchors.centerIn: parent
                    visible: !pill.occupied
                    text: pill.wsId; type: "label"; elide: Text.ElideNone
                    horizontalAlignment: Text.AlignHCenter
                    color: pill.active ? M3Theme.primaryFg
                         : pill.urgent ? M3Theme.errorFg : M3Theme.fgMuted
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: HyprlandIPC.focusWorkspace(pill.wsId) }
            }
        }
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => HyprlandIPC.dispatch(e.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
    }
}

