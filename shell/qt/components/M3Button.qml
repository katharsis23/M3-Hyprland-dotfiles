import QtQuick
import "../theme"

// variant: filled | tonal | outlined | text
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property string variant: "outlined"
    property bool toggled: false            // shorthand: toggled => filled
    property bool compact: false
    signal clicked()

    readonly property string _v: toggled ? "filled" : variant
    readonly property color _bg: !enabled ? "transparent"
        : _v === "filled" ? M3Theme.primary : _v === "tonal" ? M3Theme.secondaryContainer : "transparent"
    readonly property color _fg: !enabled ? M3Theme.alpha(M3Theme.fg, 0.38)
        : _v === "filled" ? M3Theme.primaryFg : _v === "tonal" ? M3Theme.secondaryContainerFg : M3Theme.primaryText

    implicitHeight: M3Tokens.dp(compact ? 32 : 40)
    implicitWidth: Math.max(M3Tokens.dp(48), row.implicitWidth + M3Tokens.dp(compact ? 24 : 32))
    radius: M3Tokens.cornerRadiusFull
    color: _bg
    border.width: _v === "outlined" ? 1 : 0
    border.color: M3Theme.outline
    scale: tap.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }
    Behavior on scale { NumberAnimation { duration: M3Tokens.durationShort } }

    Rectangle {
        anchors.fill: parent; radius: parent.radius; color: root._fg
        opacity: !root.enabled ? 0 : tap.pressed ? 0.14 : (hover.hovered ? 0.08 : 0)
        Behavior on opacity { NumberAnimation { duration: M3Tokens.durationShort } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: M3Tokens.dp(8)
        M3Icon { visible: root.icon !== ""; name: root.icon; size: M3Tokens.dp(18); color: root._fg }
        M3Text {
            visible: root.text !== ""
            text: root.text; type: "label"; color: root._fg; elide: Text.ElideNone
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: root.enabled; onTapped: root.clicked() }
}
