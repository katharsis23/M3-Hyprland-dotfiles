import QtQuick
import "../components"
import "../theme"
import "../core"

// Live Hyprland workspaces. Active = pill with its number, occupied = filled dot,
// empty = ring. `compact` drops the labels so it fits any bar length.
// Mouse wheel switches workspace.
Item {
    id: root
    property bool vertical: false
    property bool compact: false
    property int maxShown: 5

    readonly property int cell: M3Tokens.dp(compact ? 12 : 26)
    readonly property int activeLen: M3Tokens.dp(compact ? 26 : 44)
    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    function wsById(id) {
        const list = HyprlandIPC.numericWorkspaces
        for (let i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
        return null
    }

    Grid {
        id: grid
        columns: root.vertical ? 1 : root.maxShown
        spacing: M3Tokens.dp(root.compact ? 6 : 4)

        Repeater {
            model: root.maxShown
            delegate: Rectangle {
                id: pill
                required property int index
                readonly property int wsId: index + 1
                readonly property var ws: root.wsById(wsId)
                readonly property bool active: HyprlandIPC.activeWorkspaceId === wsId
                readonly property bool occupied: ws !== null && ws.toplevels && ws.toplevels.length > 0
                readonly property bool urgent: ws !== null && ws.urgent

                width: (active && !root.vertical) ? root.activeLen : root.cell
                height: (active && root.vertical) ? root.activeLen : root.cell
                radius: height < width ? height / 2 : width / 2
                color: active ? M3Theme.primary
                     : urgent ? M3Theme.error
                     : (occupied && root.compact) ? M3Theme.fgMuted
                     : (hover.hovered ? M3Theme.surfaceContainerHighest : "transparent")
                border.width: (!active && !urgent && !(occupied && root.compact)) ? 1 : 0
                border.color: occupied ? M3Theme.fgMuted : M3Theme.outlineVariant
                Behavior on width { NumberAnimation { duration: M3Tokens.durationMedium; easing.type: M3Tokens.easing } }
                Behavior on height { NumberAnimation { duration: M3Tokens.durationMedium; easing.type: M3Tokens.easing } }
                Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }

                M3Text {
                    anchors.centerIn: parent
                    visible: !root.compact
                    text: pill.wsId; type: "label"; elide: Text.ElideNone
                    color: pill.active ? M3Theme.primaryFg : pill.urgent ? M3Theme.errorFg
                         : pill.occupied ? M3Theme.fg : M3Theme.fgMuted
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
