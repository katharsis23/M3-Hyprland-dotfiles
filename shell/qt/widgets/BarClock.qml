import QtQuick
import Quickshell
import "../components"
import "../theme"
import "../core"

// Clock button. Horizontal: "Sun 18 Oct  14:05" (date dropped when compact).
// Vertical bar: stacked "14 / 05" so it never overflows a thin bar.
Rectangle {
    id: root
    property bool vertical: false
    property bool compact: false
    signal clicked()

    SystemClock { id: clk; precision: ConfigProvider.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }

    readonly property string timeFmt: ConfigProvider.clock24h
        ? (ConfigProvider.clockSeconds ? "HH:mm:ss" : "HH:mm")
        : (ConfigProvider.clockSeconds ? "h:mm:ss AP" : "h:mm AP")
    readonly property string label: vertical
        ? Qt.formatDateTime(clk.date, ConfigProvider.clock24h ? "HH\nmm" : "h\nmm")
        : (compact ? Qt.formatDateTime(clk.date, timeFmt)
                   : Qt.formatDateTime(clk.date, "ddd d MMM  ") + Qt.formatDateTime(clk.date, timeFmt))

    implicitWidth: txt.implicitWidth + M3Tokens.dp(vertical ? 12 : 20)
    implicitHeight: txt.implicitHeight + M3Tokens.dp(vertical ? 12 : 8)
    radius: M3Tokens.cornerRadiusFull
    color: ConfigProvider.calendarOpen ? M3Theme.secondaryContainer
         : (hover.hovered || tap.pressed ? M3Theme.surfaceContainerHighest : "transparent")
    Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }

    M3Text {
        id: txt
        anchors.centerIn: parent
        text: root.label; type: "label"; elide: Text.ElideNone
        horizontalAlignment: Text.AlignHCenter
        color: ConfigProvider.calendarOpen ? M3Theme.secondaryContainerFg : M3Theme.fg
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: root.clicked() }
}
