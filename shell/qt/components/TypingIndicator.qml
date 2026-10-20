import QtQuick
import "../theme"

// Three-dot "assistant is thinking" bubble.
Rectangle {
    id: root
    implicitWidth: row.implicitWidth + M3Tokens.dp(28)
    implicitHeight: M3Tokens.dp(36)
    radius: M3Tokens.cornerRadiusMd
    color: M3Theme.surfaceContainerHigh

    Row {
        id: row
        anchors.centerIn: parent
        spacing: M3Tokens.dp(5)
        Repeater {
            model: 3
            delegate: Rectangle {
                id: dot
                required property int index
                width: M3Tokens.dp(7); height: width; radius: width / 2
                color: M3Theme.fgMuted
                opacity: 0.35
                SequentialAnimation on opacity {
                    running: M3Tokens.motion && root.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: dot.index * 160 }
                    NumberAnimation { to: 1; duration: 320; easing.type: M3Tokens.easing }
                    NumberAnimation { to: 0.35; duration: 320; easing.type: M3Tokens.easing }
                    PauseAnimation { duration: (2 - dot.index) * 160 }
                }
            }
        }
    }
}
