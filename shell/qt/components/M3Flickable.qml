import QtQuick
import "../theme"

// Flickable with a slim themed scroll indicator (no unthemed Controls scrollbar).
Flickable {
    id: root
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Rectangle {
        parent: root
        visible: root.contentHeight > root.height + 1
        x: root.width - width - 2
        y: root.visibleArea.yPosition * root.height
        width: M3Tokens.dp(3); radius: width / 2
        height: Math.max(M3Tokens.dp(24), root.visibleArea.heightRatio * root.height)
        color: M3Theme.outline
        opacity: root.moving || root.flicking ? 0.9 : 0.35
        Behavior on opacity { NumberAnimation { duration: M3Tokens.durationMedium } }
    }
}
