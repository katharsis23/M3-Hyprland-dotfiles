import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../core"

// Dedicated wallpaper picker dialog (SUPER+CTRL+T). Shows every wallpaper found
// by WallpaperService as a thumbnail grid; picking one applies it and the whole
// Material 3 palette (kitty / fish / GTK) follows via matugen.
M3Dialog {
    id: dlg
    title: "Wallpaper"; icon: "wallpaper"
    onCloseRequested: ConfigProvider.wallpaperOpen = false
    onOpenChanged: if (open) WallpaperService.refresh()

    // Adaptive column count (min ~168dp tiles) so the grid fills the dialog.
    readonly property int cols: Math.max(2, Math.min(6, Math.floor((width - M3Tokens.dp(40)) / M3Tokens.dp(168))))

    ColumnLayout {
        anchors.fill: parent
        spacing: M3Tokens.dp(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: M3Tokens.dp(8)
            M3Text {
                Layout.fillWidth: true; type: "caption"; muted: true; wrapMode: Text.Wrap
                elide: Text.ElideNone
                text: WallpaperService.loading ? "Scanning for wallpapers…"
                      : WallpaperService.images.length + " wallpaper"
                        + (WallpaperService.images.length === 1 ? "" : "s")
            }
            M3Button {
                text: "Random"; icon: "shuffle"; variant: "tonal"; compact: true
                enabled: WallpaperService.images.length > 0
                onClicked: {
                    const list = WallpaperService.images
                    if (list.length === 0) return
                    let pick = list[Math.floor(Math.random() * list.length)]
                    // Avoid re-picking the exact same image when possible.
                    if (list.length > 1 && pick === WallpaperService.current)
                        pick = list[(list.indexOf(pick) + 1) % list.length]
                    WallpaperService.setWallpaper(pick)
                }
            }
            M3Button {
                text: "Refresh"; icon: "refresh"; variant: "outlined"; compact: true
                onClicked: WallpaperService.refresh()
            }
        }

        // Apply error (e.g. no wallpaper daemon running). Shown so the user gets
        // a real reason instead of a silently unchanged background.
        M3Text {
            Layout.fillWidth: true
            visible: WallpaperService.lastError !== ""
            type: "caption"; wrapMode: Text.Wrap; elide: Text.ElideNone
            color: M3Theme.error
            text: WallpaperService.lastError
        }

        M3Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: width
            contentHeight: grid.implicitHeight

            GridLayout {
                id: grid
                width: parent.width
                columns: dlg.cols
                columnSpacing: M3Tokens.dp(10); rowSpacing: M3Tokens.dp(10)

                Repeater {
                    model: WallpaperService.images
                    delegate: Item {
                        id: cell
                        required property string modelData
                        readonly property bool current: WallpaperService.current === modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: thumb.height + M3Tokens.dp(30)

                        Rectangle {
                            id: thumb
                            width: parent.width
                            height: Math.round(width * 0.62)
                            radius: M3Tokens.cornerRadiusLg
                            clip: true
                            color: M3Theme.surfaceContainerHighest
                            border.width: cell.current ? 3 : 1
                            border.color: cell.current ? M3Theme.primary : M3Theme.outlineVariant
                            scale: tap.pressed ? 0.97 : (hov.hovered ? 1.02 : 1)
                            Behavior on scale { NumberAnimation { duration: M3Tokens.durationShort } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: WallpaperService.fileUrl(cell.modelData)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: Math.round(thumb.width * 2)
                                sourceSize.height: Math.round(thumb.height * 2)
                            }
                            // "Current" badge
                            Rectangle {
                                visible: cell.current
                                anchors { top: parent.top; right: parent.right; margins: M3Tokens.dp(6) }
                                implicitWidth: badge.implicitWidth + M3Tokens.dp(14); implicitHeight: M3Tokens.dp(22)
                                radius: height / 2
                                color: M3Theme.primary
                                RowLayout {
                                    id: badge
                                    anchors.centerIn: parent
                                    spacing: M3Tokens.dp(4)
                                    M3Icon { name: "check"; size: M3Tokens.dp(14); color: M3Theme.primaryFg }
                                    M3Text { text: "Current"; type: "caption"; color: M3Theme.primaryFg; elide: Text.ElideNone }
                                }
                            }
                            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { id: tap; onTapped: WallpaperService.setWallpaper(cell.modelData) }
                        }

                        M3Text {
                            anchors { top: thumb.bottom; topMargin: M3Tokens.dp(4); left: parent.left; right: parent.right }
                            text: WallpaperService.baseName(cell.modelData)
                            type: "caption"; muted: !cell.current
                            color: cell.current ? M3Theme.primaryText : M3Theme.fgMuted
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
        }

        // Empty state / next steps
        M3Text {
            Layout.fillWidth: true; Layout.topMargin: M3Tokens.dp(4)
            visible: !WallpaperService.loading && WallpaperService.images.length === 0
            type: "caption"; muted: true; wrapMode: Text.Wrap; elide: Text.ElideNone
            text: "No wallpapers found. Add images to ~/Pictures/Wallpapers (or set $WALLPAPER_DIR) and press Refresh."
        }
    }
}
