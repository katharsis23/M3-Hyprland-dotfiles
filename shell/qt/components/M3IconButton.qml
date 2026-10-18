import QtQuick
import "../theme"

Rectangle {
    id: root
    property string icon: "circle"
    property bool toggled: false
    property bool filled: false
    property int size: M3Tokens.dp(36)
    property string tooltip: ""         // only shown where the host window is big enough (overlay panels)
    signal clicked()

    readonly property bool _active: toggled || filled
    readonly property color _fg: !enabled ? M3Theme.alpha(M3Theme.fg, 0.38)
                               : filled ? M3Theme.primaryFg
                               : toggled ? M3Theme.secondaryContainerFg : M3Theme.fgMuted

    implicitWidth: size; implicitHeight: size
    radius: M3Tokens.cornerRadiusFull
    color: filled ? M3Theme.primary : (toggled ? M3Theme.secondaryContainer : "transparent")
    scale: tap.pressed ? 0.92 : 1
    Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }
    Behavior on scale { NumberAnimation { duration: M3Tokens.durationShort; easing.type: M3Tokens.easing } }

    Rectangle {                                 // state layer
        anchors.fill: parent; radius: parent.radius
        color: root._fg
        opacity: !root.enabled ? 0 : tap.pressed ? 0.16 : (hover.hovered ? 0.10 : 0)
        Behavior on opacity { NumberAnimation { duration: M3Tokens.durationShort } }
    }
    M3Icon {
        anchors.centerIn: parent
        name: root.icon; size: Math.round(root.size * 0.58)
        color: root._fg
    }
    Rectangle {                                 // tooltip
        visible: opacity > 0
        opacity: (root.tooltip !== "" && hover.hovered && !tap.pressed) ? 1 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom; anchors.topMargin: M3Tokens.dp(6)
        z: 100
        implicitWidth: tipText.implicitWidth + M3Tokens.dp(16); implicitHeight: M3Tokens.dp(26)
        radius: M3Tokens.cornerRadiusSm
        color: M3Theme.surfaceContainerHighest
        border.width: 1; border.color: M3Theme.outlineVariant
        Behavior on opacity { NumberAnimation { duration: M3Tokens.durationShort } }
        M3Text { id: tipText; anchors.centerIn: parent; text: root.tooltip; type: "caption"; elide: Text.ElideNone }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: root.enabled; onTapped: root.clicked() }
}
