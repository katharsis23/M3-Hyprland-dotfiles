import QtQuick
import "../theme"

// variant: filled | outlined | elevated
Rectangle {
    id: root
    default property alias content: inner.data
    property int padding: M3Tokens.spaceMd
    property string variant: "filled"

    color: variant === "elevated" ? M3Theme.surfaceContainerLow : M3Theme.surfaceContainerHighest
    radius: M3Tokens.cornerRadiusLg
    border.width: variant === "outlined" ? 1 : 0
    border.color: M3Theme.outlineVariant
    implicitWidth: M3Tokens.dp(120)
    implicitHeight: inner.childrenRect.height + padding * 2

    Item {
        id: inner
        anchors { fill: parent; margins: root.padding }
    }
}
