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
PanelWindow {
    id: bar

    readonly property string screenName: screen ? screen.name : ""
    readonly property string pos: ConfigProvider.barPosition
    readonly property bool vertical: pos === "left" || pos === "right"
    readonly property bool floating: M3Tokens.barFloating
    readonly property int thickness: M3Tokens.barThickness
    readonly property real length: vertical ? height : width
    readonly property bool compact: length < M3Tokens.dp(820)     // drop shortcuts, date, bluetooth
    readonly property bool tiny: length < M3Tokens.dp(520)        // also drop file manager, workspace labels
    readonly property bool showTitle: !vertical && length > M3Tokens.dp(1100)
    readonly property int btn: M3Tokens.dp(32)

    anchors {
        top: pos !== "bottom"
        bottom: pos !== "top"
        left: pos !== "right"
        right: pos !== "left"
    }
    margins { top: M3Tokens.barGap; bottom: M3Tokens.barGap; left: M3Tokens.barGap; right: M3Tokens.barGap }
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
                    Layout.maximumWidth: M3Tokens.dp(280)
                    Layout.leftMargin: M3Tokens.dp(8); Layout.rightMargin: M3Tokens.dp(10)
                    text: HyprlandIPC.activeTitle; type: "label"; muted: true
                    elide: Text.ElideMiddle
                }
            }
        }

        // ---- center (true centre: start and end share equal widths) -----
        BarIsland {
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
                M3IconButton { icon: "smart_toy"; size: bar.btn; tooltip: "AI assistant (Super+Alt+L)"
                               toggled: ConfigProvider.leftSidebarOpen
                               onClicked: ConfigProvider.toggleLeftSidebar(bar.screenName) }
                M3IconButton { icon: "dock_to_left"; size: bar.btn; tooltip: "System sidebar (Super+D)"
                               toggled: ConfigProvider.sidebarOpen
                               onClicked: ConfigProvider.toggleSidebar(bar.screenName) }
            }
        }
    }
}
