import QtQuick
import QtQuick.Controls
import "../theme"

TextField {
    id: root
    property string icon: ""
    implicitHeight: M3Tokens.dp(46)
    leftPadding: icon !== "" ? M3Tokens.dp(46) : M3Tokens.dp(18)
    rightPadding: M3Tokens.dp(16)
    color: M3Theme.fg
    placeholderTextColor: M3Theme.fgMuted
    selectionColor: M3Theme.primary
    selectedTextColor: M3Theme.primaryFg
    font.family: Typography.family
    font.pixelSize: Typography.bodyLarge
    selectByMouse: true
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: M3Tokens.cornerRadiusFull
        color: M3Theme.surfaceContainerHighest
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? M3Theme.primary : M3Theme.outlineVariant
        Behavior on border.color { ColorAnimation { duration: M3Tokens.durationShort } }
        M3Icon {
            visible: root.icon !== ""
            anchors { left: parent.left; leftMargin: M3Tokens.dp(15); verticalCenter: parent.verticalCenter }
            name: root.icon; size: M3Tokens.dp(20)
            color: root.activeFocus ? M3Theme.primaryText : M3Theme.fgMuted
        }
    }
}
