import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import "../theme"
import "../core"

// CPU & RAM from /proc (no Python needed). Only samples while `active`.
M3Card {
    id: root
    property bool active: true
    property real cpu: 0          // 0..1
    property real ram: 0          // 0..1
    property string ramText: "-- / -- GB"
    property var _prev: null
    implicitHeight: col.implicitHeight + padding * 2

    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = parts[3] + (parts[4] || 0)
                const total = parts.reduce((a, b) => a + b, 0)
                if (root._prev) {
                    const dt = total - root._prev.total, di = idle - root._prev.idle
                    if (dt > 0) root.cpu = Math.max(0, Math.min(1, 1 - di / dt))
                }
                root._prev = { total: total, idle: idle }
            }
        }
    }
    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {}
                this.text.split("\n").forEach(l => { const r = l.match(/^(\w+):\s+(\d+)/); if (r) m[r[1]] = Number(r[2]) })
                if (m.MemTotal) {
                    const total = m.MemTotal / 1048576, used = total - (m.MemAvailable || m.MemFree || 0) / 1048576
                    root.ram = Math.max(0, Math.min(1, used / total))
                    root.ramText = used.toFixed(1) + " / " + total.toFixed(1) + " GB"
                }
            }
        }
    }
    Timer { interval: 1500; running: root.active; repeat: true; triggeredOnStart: true
            onTriggered: { cpuProc.running = true; memProc.running = true } }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: M3Tokens.dp(8)
        M3Text { text: "System"; type: "title"; Layout.fillWidth: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: M3Tokens.dp(8)
            ArcGauge { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: width
                       Layout.maximumHeight: M3Tokens.dp(130); value: root.cpu; label: "CPU"
                       accent: M3Theme.primary }
            ArcGauge { Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: width
                       Layout.maximumHeight: M3Tokens.dp(130); value: root.ram; label: "RAM"
                       accent: M3Theme.tertiary }
        }
        M3Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                 text: root.ramText; type: "caption"; muted: true }
    }
}
