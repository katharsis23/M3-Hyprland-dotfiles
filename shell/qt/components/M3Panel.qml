import QtQuick
import "../theme"

// Floating glass surface used by every overlay (popups, drawer, dialogs).
Rectangle {
    id: root
    property bool open: false
    property real reveal: open ? 1 : 0
    property real lift: M3Tokens.dp(8)          // slide distance while fading in
    Behavior on reveal { NumberAnimation { duration: M3Tokens.durationMedium; easing.type: M3Tokens.easing } }

    visible: reveal > 0.001
    opacity: reveal
    scale: 0.97 + 0.03 * reveal
    radius: M3Tokens.cornerRadiusXl
    color: M3Theme.surfaceGlass
    border.width: 1
    border.color: M3Theme.alpha(M3Theme.outline, 0.35)

    Rectangle {                                  // soft drop shadow
        z: -1
        anchors { fill: parent; margins: -M3Tokens.dp(1); topMargin: M3Tokens.dp(2); bottomMargin: -M3Tokens.dp(3) }
        radius: parent.radius + M3Tokens.dp(2)
        color: M3Theme.shadow
    }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // swallow clicks: don't reach the scrim
}
