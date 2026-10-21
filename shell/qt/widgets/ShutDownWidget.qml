import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import "../theme"

// Session / power actions: power off, reboot, log out and lock.
// The body of the power popup (hosted by ShutdownPanel inside OverlayLayer);
// it draws no surface of its own, so it stays reusable in any panel.
//
// A plain GridLayout with two fixed-size rows. It deliberately does NOT rely
// on nested layouts for its implicit size (a GridLayout with fillWidth children
// reports 0 implicit height until it is given a width, which collapsed the
// host panel to nothing); instead `implicitHeight` is computed from the button
// metrics so the popup always has a real size.
GridLayout {
    id: root
    columns: 2
    columnSpacing: M3Tokens.spaceSm
    rowSpacing: M3Tokens.spaceSm

    readonly property int cellW: M3Tokens.dp(120)
    readonly property int cellH: M3Tokens.dp(40)
    readonly property int rows: 2
    implicitWidth: cellW * columns + columnSpacing * (columns - 1)
    implicitHeight: cellH * rows + rowSpacing * (rows - 1)

    // ---- power actions ---------------------------------------------------
    // Each helper guards against double-invocation while a command is already
    // running, so a stray double click can never fire, say, two shutdowns.
    readonly property bool _busy: shutdownProc.running || rebootProc.running || logoutProc.running || lockProc.running

    function powerOff() { if (!_busy) shutdownProc.running = true }
    function reboot()   { if (!_busy) rebootProc.running = true }
    function logOut()   { if (!_busy) logoutProc.running = true }
    function lock()     { if (!_busy) lockProc.running = true }

    // systemctl poweroff/reboot work on both systemd-logind and root setups.
    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
    Process { id: rebootProc;   command: ["systemctl", "reboot"] }
    // Logging out of the Hyprland session.
    Process { id: logoutProc;   command: ["hyprctl", "dispatch", "exit"] }
    Process { id: lockProc;     command: ["hyprlock"] }

    M3Button {
        Layout.preferredWidth: root.cellW
        Layout.preferredHeight: root.cellH
        text: "Power off"; icon: "power_settings_new"
        variant: "tonal"
        enabled: !root._busy
        onClicked: root.powerOff()
    }
    M3Button {
        Layout.preferredWidth: root.cellW
        Layout.preferredHeight: root.cellH
        text: "Reboot"; icon: "restart_alt"
        variant: "tonal"
        enabled: !root._busy
        onClicked: root.reboot()
    }
    M3Button {
        Layout.preferredWidth: root.cellW
        Layout.preferredHeight: root.cellH
        text: "Log out"; icon: "logout"
        variant: "outlined"
        enabled: !root._busy
        onClicked: root.logOut()
    }
    M3Button {
        Layout.preferredWidth: root.cellW
        Layout.preferredHeight: root.cellH
        text: "Lock"; icon: "lock"
        variant: "outlined"
        enabled: !root._busy
        onClicked: root.lock()
    }
}
