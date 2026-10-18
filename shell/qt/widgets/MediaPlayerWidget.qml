import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../components"
import "../theme"
import "../core"

// MPRIS player: prefers the one that is playing, otherwise the first.
M3Card {
    id: root
    property bool active: true
    readonly property var players: Mpris.players.values
    readonly property var player: {
        for (let i = 0; i < players.length; i++) if (players[i].isPlaying) return players[i]
        return players.length > 0 ? players[0] : null
    }
    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.isPlaying
    readonly property real progress: (hasPlayer && player.length > 0)
        ? Math.max(0, Math.min(1, player.position / player.length)) : 0
    implicitHeight: col.implicitHeight + padding * 2

    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60) }

    Timer { interval: 1000; repeat: true; running: root.active && root.playing
            onTriggered: root.player.positionChanged() }   // MPRIS doesn't push position updates

    ColumnLayout {
        id: col
        width: parent.width
        spacing: M3Tokens.dp(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: M3Tokens.dp(12)
            Rectangle {
                Layout.preferredWidth: M3Tokens.dp(76); Layout.preferredHeight: M3Tokens.dp(76)
                radius: M3Tokens.cornerRadiusMd; clip: true
                color: M3Theme.primaryContainer
                Image { id: art; anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop
                        source: root.hasPlayer ? (root.player.trackArtUrl || "") : ""
                        visible: status === Image.Ready }
                M3Icon { anchors.centerIn: parent; visible: !art.visible; name: "music_note"
                         size: M3Tokens.dp(36); color: M3Theme.primaryContainerFg }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: M3Tokens.dp(2)
                M3Text { Layout.fillWidth: true; type: "title"
                         text: root.hasPlayer ? (root.player.trackTitle || "Unknown title") : "Nothing playing" }
                M3Text { Layout.fillWidth: true; muted: true
                         text: root.hasPlayer ? (root.player.trackArtist || root.player.identity || "") : "Start a player to control it here" }
            }
        }

        Rectangle {                                     // seek bar
            Layout.fillWidth: true; Layout.preferredHeight: M3Tokens.dp(6)
            radius: height / 2; color: M3Theme.secondaryContainer
            Rectangle { width: parent.width * root.progress; height: parent.height; radius: parent.radius
                        color: M3Theme.primary
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.Linear } } }
            MouseArea {
                anchors { fill: parent; topMargin: -M3Tokens.dp(8); bottomMargin: -M3Tokens.dp(8) }
                enabled: root.hasPlayer && root.player.canSeek && root.player.length > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: (e) => root.player.position = root.player.length * Math.max(0, Math.min(1, e.x / width))
            }
        }
        RowLayout {
            Layout.fillWidth: true
            M3Text { text: root.hasPlayer ? root.fmt(root.player.position) : "0:00"; type: "caption"; muted: true; elide: Text.ElideNone }
            Item { Layout.fillWidth: true }
            M3Text { text: root.hasPlayer ? root.fmt(root.player.length) : "0:00"; type: "caption"; muted: true; elide: Text.ElideNone }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: M3Tokens.dp(8)
            M3IconButton { icon: "skip_previous"; size: M3Tokens.dp(44)
                           enabled: root.hasPlayer && root.player.canGoPrevious; onClicked: root.player.previous() }
            M3IconButton { icon: root.playing ? "pause" : "play_arrow"; size: M3Tokens.dp(54); filled: true
                           enabled: root.hasPlayer && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
            M3IconButton { icon: "skip_next"; size: M3Tokens.dp(44)
                           enabled: root.hasPlayer && root.player.canGoNext; onClicked: root.player.next() }
        }
    }
}
