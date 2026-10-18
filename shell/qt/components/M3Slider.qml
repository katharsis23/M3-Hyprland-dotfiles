import QtQuick
import QtQuick.Controls
import "../theme"

Slider {
    id: root
    property string icon: ""
    property bool showValue: false
    from: 0; to: 100; value: 50
    implicitHeight: M3Tokens.dp(44)
    hoverEnabled: true

    background: Item {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: M3Tokens.dp(28)
        Rectangle {
            anchors.fill: parent; radius: M3Tokens.dp(10)
            color: M3Theme.secondaryContainer
            clip: true
            Rectangle {
                width: Math.max(parent.height, root.visualPosition * parent.width)
                height: parent.height; radius: parent.radius
                color: root.enabled ? M3Theme.primary : M3Theme.outline
            }
        }
        M3Icon {
            visible: root.icon !== ""
            anchors { left: parent.left; leftMargin: M3Tokens.dp(8); verticalCenter: parent.verticalCenter }
            name: root.icon; size: M3Tokens.dp(18)
            color: M3Theme.primaryFg
        }
        M3Text {
            visible: root.showValue
            anchors { right: parent.right; rightMargin: M3Tokens.dp(10); verticalCenter: parent.verticalCenter }
            text: Math.round(root.value); type: "caption"; elide: Text.ElideNone
            color: M3Theme.secondaryContainerFg
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.pressed ? M3Tokens.dp(5) : M3Tokens.dp(4)
        height: M3Tokens.dp(36); radius: width / 2
        color: M3Theme.primaryText
        Behavior on width { NumberAnimation { duration: M3Tokens.durationShort } }
    }
}
