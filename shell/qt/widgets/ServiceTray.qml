import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../core"

// One compact "status cluster" button: Wi-Fi, Bluetooth, volume, battery.
// Opens Quick Settings. `compact` hides the less important icons and the % text.
Rectangle {
    id: root
    property bool vertical: false
    property bool compact: false
    signal clicked()

    readonly property int iconSize: M3Tokens.dp(18)
    implicitWidth: grid.implicitWidth + M3Tokens.dp(vertical ? 12 : 20)
    implicitHeight: grid.implicitHeight + M3Tokens.dp(vertical ? 16 : 8)
    radius: M3Tokens.cornerRadiusFull
    color: hover.hovered || tap.pressed ? M3Theme.surfaceContainerHighest : "transparent"
    Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 8
        columnSpacing: M3Tokens.dp(8); rowSpacing: M3Tokens.dp(8)

        M3Icon { size: root.iconSize
            name: SystemServices.online ? "wifi" : (SystemServices.wifiEnabled ? "wifi_find" : "wifi_off")
            color: SystemServices.wifiEnabled ? M3Theme.fg : M3Theme.fgMuted }
        M3Icon { size: root.iconSize; visible: !root.compact
            name: SystemServices.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
            color: SystemServices.bluetoothEnabled ? M3Theme.fg : M3Theme.fgMuted }
        M3Icon { size: root.iconSize
            name: SystemServices.muted ? "volume_off" : SystemServices.volumePercent === 0 ? "volume_mute"
                : SystemServices.volumePercent < 50 ? "volume_down" : "volume_up"
            color: SystemServices.muted ? M3Theme.fgMuted : M3Theme.fg }
        M3Icon { size: root.iconSize; visible: !!SystemServices.battery
            name: SystemServices.batteryIcon()
            color: (!SystemServices.charging && SystemServices.batteryPercent < 0.15) ? M3Theme.error : M3Theme.fg }
        M3Text {
            visible: !!SystemServices.battery && !root.compact && !root.vertical
            text: Math.round(SystemServices.batteryPercent * 100) + "%"
            type: "label"; elide: Text.ElideNone
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: root.clicked() }
}
