import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components"
import "../widgets"
import "../theme"
import "../core"

M3Panel {
    id: panel
    readonly property int pad: M3Tokens.dp(16)
    implicitHeight: col.implicitHeight + pad * 2

    SystemClock { id: clk; precision: SystemClock.Seconds }

    M3Flickable {
        anchors { fill: parent; margins: panel.pad }
        contentWidth: width; contentHeight: col.implicitHeight
        ColumnLayout {
            id: col
            width: parent.width; spacing: M3Tokens.dp(10)
            M3Text { Layout.fillWidth: true; type: "display"; horizontalAlignment: Text.AlignHCenter
                     text: Qt.formatDateTime(clk.date, ConfigProvider.clock24h ? "HH:mm" : "h:mm AP") }
            M3Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; muted: true
                     text: Qt.formatDateTime(clk.date, "dddd, d MMMM yyyy") }
            CalendarWidget { Layout.fillWidth: true; Layout.topMargin: M3Tokens.dp(6) }
        }
    }
}
