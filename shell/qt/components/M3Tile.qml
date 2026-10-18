import QtQuick
import QtQuick.Layouts
import "../theme"

// Quick-settings toggle tile.
Rectangle {
    id: tile
    property string label: ""
    property string icon: ""
    property string detail: ""
    property bool active: false
    signal tapped()

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: M3Tokens.dp(68)
    radius: active ? M3Tokens.cornerRadiusLg : M3Tokens.cornerRadiusXl
    color: active ? M3Theme.primaryContainer : M3Theme.surfaceContainerHighest
    scale: tap.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: M3Tokens.durationMedium } }
    Behavior on radius { NumberAnimation { duration: M3Tokens.durationMedium; easing.type: M3Tokens.easing } }
    Behavior on scale { NumberAnimation { duration: M3Tokens.durationShort } }

    RowLayout {
        anchors { fill: parent; margins: M3Tokens.dp(12) }
        spacing: M3Tokens.dp(10)
        Rectangle {
            implicitWidth: M3Tokens.dp(40); implicitHeight: M3Tokens.dp(40); radius: width / 2
            color: tile.active ? M3Theme.primary : M3Theme.surfaceContainer
            M3Icon { anchors.centerIn: parent; name: tile.icon; size: M3Tokens.dp(22)
                     color: tile.active ? M3Theme.primaryFg : M3Theme.fgMuted }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 0
            M3Text { Layout.fillWidth: true; text: tile.label; type: "label"
                     color: tile.active ? M3Theme.primaryContainerFg : M3Theme.fg }
            M3Text { Layout.fillWidth: true; text: tile.detail; type: "caption"
                     color: tile.active ? M3Theme.primaryContainerFg : M3Theme.fgMuted
                     opacity: tile.active ? 0.85 : 1 }
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: tile.tapped() }
}
