import QtQuick
import "../theme"

Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: M3Tokens.dp(52); implicitHeight: M3Tokens.dp(32)
    radius: height / 2
    color: checked ? M3Theme.primary : M3Theme.surfaceContainerHighest
    border.width: checked ? 0 : 2
    border.color: M3Theme.outline
    Behavior on color { ColorAnimation { duration: M3Tokens.durationMedium } }

    Rectangle {
        id: thumb
        property int d: root.checked ? M3Tokens.dp(24) : (tap.pressed ? M3Tokens.dp(20) : M3Tokens.dp(16))
        width: d; height: d; radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - M3Tokens.dp(4) : M3Tokens.dp(8) + (M3Tokens.dp(16) - d) / 2
        color: root.checked ? M3Theme.primaryFg : M3Theme.outline
        Behavior on x { NumberAnimation { duration: M3Tokens.durationMedium; easing.type: M3Tokens.easing } }
        Behavior on d { NumberAnimation { duration: M3Tokens.durationShort } }
        Behavior on color { ColorAnimation { duration: M3Tokens.durationMedium } }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: { root.checked = !root.checked; root.toggled(root.checked) } }
}
