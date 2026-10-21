import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"
import "../core"
import "../widgets"
import "../components"

// Adaptive bar: top / bottom / left / right, float (separate "islands") or hug
// (one edge-to-edge strip). Modules drop out by priority when the bar is short,
// and the clock/tray re-orient themselves on vertical bars.
//
// Priority (first to go -> last to go):
//   window title  ->  shortcuts button  ->  file manager + AI button  ->  tray/clock detail
// The launcher, workspaces, clock and system-sidebar button always stay.
PanelWindow {
    id: bar

    readonly property string screenName: screen ? screen.name : ""
    readonly property string pos: ConfigProvider.barPosition
    readonly property bool vertical: pos === "left" || pos === "right"
    readonly property bool floating: M3Tokens.barFloating
    readonly property int thickness: M3Tokens.barThickness
    // Hug mode is a true edge-to-edge strip, so it takes no outer gap.
    readonly property int edgeGap: floating ? M3Tokens.barGap : 0

    // ---- adaptivity ------------------------------------------------------
    // Length along the bar's axis. Based on the screen so it is correct on the very
    // first frame (a PanelWindow reports width/height 0 until the compositor
    // configures it, which used to flash the bar in its smallest layout).
    readonly property real length: {
        const full = (screen && (vertical ? screen.height : screen.width) > 0)
                     ? (vertical ? screen.height : screen.width)
                     : (vertical ? height : width)
        return full > 0 ? full - 2 * edgeGap : 100000
    }
    // Breakpoints in one place; tune these if you add widgets.
    readonly property real compactBelow: M3Tokens.dp(820)   // drop shortcuts, date, bluetooth
    readonly property real tinyBelow: M3Tokens.dp(520)      // also drop file manager, AI, workspace labels
    readonly property bool compact: length < compactBelow
    readonly property bool tiny: length < tinyBelow

    // Buttons shrink if the bar is thin enough that 32dp ones would touch the island edge.
    readonly property int islandPad: M3Tokens.dp(4)
    readonly property int cross: thickness - (floating ? 0 : M3Tokens.dp(8))
    readonly property int btn: Math.max(M3Tokens.dp(24), Math.min(M3Tokens.dp(32), cross - islandPad * 2))

    // The title only appears if it genuinely fits beside the (true-centre) workspace
    // island, measured from real widths instead of a fixed screen-size guess.
    readonly property int startButtons: 1 + (tiny ? 0 : 1) + (compact ? 0 : 1)
    readonly property real titleRoom: {
        if (vertical) return 0
        const gap = M3Tokens.dp(2)
        const buttons = startButtons * btn + (startButtons - 1) * gap + islandPad * 2
        const share = (length - centerIsland.implicitWidth) / 2 - M3Tokens.dp(6)  // minus column spacing
        return share - buttons - gap - M3Tokens.dp(18)                           // minus title margins
    }
    readonly property bool showTitle: titleRoom >= M3Tokens.dp(96)

    anchors {
        top: pos !== "bottom"
        bottom: pos !== "top"
        left: pos !== "right"
        right: pos !== "left"
    }
    margins { top: bar.edgeGap; bottom: bar.edgeGap; left: bar.edgeGap; right: bar.edgeGap }
    implicitHeight: vertical ? 0 : thickness
    implicitWidth: vertical ? thickness : 0
    color: "transparent"
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.namespace: "m3shell-bar"
    WlrLayershell.layer: WlrLayer.Top

    // hug mode: one continuous strip
    Rectangle {
        visible: !bar.floating
        anchors.fill: parent
        color: M3Theme.surfaceGlass
        Rectangle {                              // hairline on the inner edge
            color: M3Theme.alpha(M3Theme.outline, 0.30)
            width: bar.vertical ? 1 : parent.width; height: bar.vertical ? parent.height : 1
            x: bar.pos === "left" ? parent.width - 1 : 0
            y: bar.pos === "top" ? parent.height - 1 : 0
        }
    }

    GridLayout {
        anchors { fill: parent; margins: bar.floating ? 0 : M3Tokens.dp(4) }
        columns: bar.vertical ? 1 : 3
        rowSpacing: M3Tokens.dp(6); columnSpacing: M3Tokens.dp(6)

        // ---- start ------------------------------------------------------
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 1; Layout.preferredHeight: 1
            Layout.minimumWidth: 0; Layout.minimumHeight: 0
            BarIsland {
                vertical: bar.vertical; floating: bar.floating; thickness: bar.thickness
                anchors {
                    left: bar.vertical ? undefined : parent.left
                    top: bar.vertical ? parent.top : undefined
                    verticalCenter: bar.vertical ? undefined : parent.verticalCenter
                    horizontalCenter: bar.vertical ? parent.horizontalCenter : undefined
                }
                M3IconButton { icon: "rocket_launch"; size: bar.btn; tooltip: "Launcher (Super+Space)"
                               onClicked: LauncherService.toggle() }
                M3IconButton { visible: !bar.tiny; icon: "folder"; size: bar.btn; onClicked: HyprlandIPC.exec("nemo") }
                M3IconButton { visible: !bar.compact; icon: "keyboard"; size: bar.btn
                               toggled: ConfigProvider.shortcutsOpen
                               onClicked: ConfigProvider.toggleShortcuts(bar.screenName) }
                M3Text {
                    visible: bar.showTitle && HyprlandIPC.activeTitle !== ""
                    Layout.maximumWidth: Math.min(M3Tokens.dp(320), Math.max(0, bar.titleRoom))
                    Layout.leftMargin: M3Tokens.dp(8); Layout.rightMargin: M3Tokens.dp(10)
                    text: HyprlandIPC.activeTitle; type: "label"; muted: true
                    elide: Text.ElideMiddle
                }
            }
        }

        // ---- center (true centre: start and end share equal widths) -----
        BarIsland {
            id: centerIsland
            vertical: bar.vertical; floating: bar.floating; thickness: bar.thickness
            Layout.alignment: Qt.AlignCenter
            WorkspaceBar {
                vertical: bar.vertical; compact: bar.tiny
                Layout.margins: M3Tokens.dp(4)
            }
        }

        // ---- end --------------------------------------------------------
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.preferredWidth: 1; Layout.preferredHeight: 1
            Layout.minimumWidth: 0; Layout.minimumHeight: 0
            BarIsland {
                vertical: bar.vertical; floating: bar.floating; thickness: bar.thickness
                anchors {
                    right: bar.vertical ? undefined : parent.right
                    bottom: bar.vertical ? parent.bottom : undefined
                    verticalCenter: bar.vertical ? undefined : parent.verticalCenter
                    horizontalCenter: bar.vertical ? parent.horizontalCenter : undefined
                }
                ServiceTray { vertical: bar.vertical; compact: bar.compact
                              onClicked: ConfigProvider.toggleQuickSettings(bar.screenName) }
                BarClock { vertical: bar.vertical; compact: bar.compact
                           onClicked: ConfigProvider.toggleCalendar(bar.screenName) }
                M3IconButton { visible: !bar.tiny; icon: "smart_toy"; size: bar.btn; tooltip: "AI assistant (Super+Alt+L)"
                               toggled: ConfigProvider.leftSidebarOpen
                               onClicked: ConfigProvider.toggleLeftSidebar(bar.screenName) }
                M3IconButton { icon: "dock_to_left"; size: bar.btn; tooltip: "System sidebar (Super+D)"
                               toggled: ConfigProvider.sidebarOpen
                               onClicked: ConfigProvider.toggleSidebar(bar.screenName) }
                M3IconButton { icon: "power_settings_new"; size: bar.btn; tooltip: "Power menu"
                               toggled: ConfigProvider.shutdownOpen
                               onClicked: ConfigProvider.toggleShutdown(bar.screenName) }
            }
        }
    }
}
