import QtQuick
import QtQuick.Layouts
import "../theme"

// options: [{ value, label, icon? }]
Rectangle {
    id: root
    property var options: []
    property var current
    signal picked(var value)

    implicitHeight: M3Tokens.dp(44)
    implicitWidth: row.implicitWidth + M3Tokens.dp(8)
    radius: M3Tokens.cornerRadiusFull
    color: M3Theme.surfaceContainerHighest

    RowLayout {
        id: row
        anchors { fill: parent; margins: M3Tokens.dp(4) }
        spacing: M3Tokens.dp(4)
        Repeater {
            model: root.options
            delegate: Rectangle {
                id: seg
                required property var modelData
                readonly property bool sel: root.current === modelData.value
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumWidth: 0
                implicitWidth: lbl.implicitWidth + M3Tokens.dp(32)
                radius: M3Tokens.cornerRadiusFull
                color: sel ? M3Theme.primary : (hover.hovered ? M3Theme.surfaceContainerHigh : "transparent")
                Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }
                RowLayout {
                    anchors { fill: parent; leftMargin: M3Tokens.dp(10); rightMargin: M3Tokens.dp(10) }
                    spacing: M3Tokens.dp(6)
                    Item { Layout.fillWidth: true }
                    M3Icon { visible: !!seg.modelData.icon; name: seg.modelData.icon || ""
                             size: M3Tokens.dp(18); color: seg.sel ? M3Theme.primaryFg : M3Theme.fgMuted }
                    M3Text { id: lbl; text: seg.modelData.label; type: "label"
                             Layout.maximumWidth: seg.width - M3Tokens.dp(20)
                             color: seg.sel ? M3Theme.primaryFg : M3Theme.fg }
                    Item { Layout.fillWidth: true }
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.picked(seg.modelData.value) }
            }
        }
    }
}
