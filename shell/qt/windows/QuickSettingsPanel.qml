import QtQuick
import QtQuick.Layouts
import Quickshell
import "../components"
import "../theme"
import "../core"

M3Panel {
    id: panel
    readonly property int pad: M3Tokens.dp(16)
    implicitHeight: col.implicitHeight + pad * 2

    SystemClock { id: clk; precision: SystemClock.Minutes }

    M3Flickable {
        anchors { fill: parent; margins: panel.pad }
        contentWidth: width; contentHeight: col.implicitHeight

        ColumnLayout {
            id: col
            width: parent.width
            spacing: M3Tokens.dp(12)

            RowLayout {
                Layout.fillWidth: true
                spacing: M3Tokens.dp(4)
                ColumnLayout {
                    Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 0
                    M3Text { Layout.fillWidth: true; type: "headline"
                             text: Qt.formatDateTime(clk.date, ConfigProvider.clock24h ? "HH:mm" : "h:mm AP") }
                    M3Text { Layout.fillWidth: true; muted: true
                             text: Qt.formatDateTime(clk.date, "dddd, d MMMM") }
                }
                M3IconButton { icon: ConfigProvider.darkMode ? "light_mode" : "dark_mode"
                               tooltip: ConfigProvider.darkMode ? "Light theme" : "Dark theme"
                               onClicked: ConfigProvider.darkMode = !ConfigProvider.darkMode }
                M3IconButton { icon: "wallpaper"; tooltip: "Wallpaper (Super+Ctrl+T)"
                               onClicked: ConfigProvider.toggleWallpaper(ConfigProvider.overlayScreen) }
                M3IconButton { icon: "keyboard"; tooltip: "Shortcuts"
                               onClicked: ConfigProvider.toggleShortcuts(ConfigProvider.overlayScreen) }
                M3IconButton { icon: "settings"; tooltip: "Settings"
                               onClicked: ConfigProvider.toggleSettings(ConfigProvider.overlayScreen) }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: panel.width > M3Tokens.dp(330) ? 2 : 1
                columnSpacing: M3Tokens.dp(8); rowSpacing: M3Tokens.dp(8)
                M3Tile { label: "Wi-Fi"; icon: SystemServices.wifiEnabled ? "wifi" : "wifi_off"
                         active: SystemServices.wifiEnabled
                         detail: !SystemServices.wifiEnabled ? "Off" : (SystemServices.online ? "Connected" : "Not connected")
                         onTapped: SystemServices.toggleWifi() }
                M3Tile { label: "Bluetooth"; icon: SystemServices.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
                         active: SystemServices.bluetoothEnabled
                         detail: SystemServices.bluetoothEnabled ? "On" : "Off"
                         onTapped: SystemServices.toggleBluetooth() }
                M3Tile { label: "Night light"; icon: "nightlight"; active: ConfigProvider.nightLight
                         detail: ConfigProvider.nightLight ? "On" : "Off"
                         onTapped: { ConfigProvider.nightLight = !ConfigProvider.nightLight
                                     SystemServices.setNightLight(ConfigProvider.nightLight) } }
                M3Tile { label: "Do not disturb"; icon: ConfigProvider.dnd ? "notifications_off" : "notifications"
                         active: ConfigProvider.dnd; detail: ConfigProvider.dnd ? "On" : "Off"
                         onTapped: ConfigProvider.dnd = !ConfigProvider.dnd }
            }

            M3Card {
                Layout.fillWidth: true
                implicitHeight: sliders.implicitHeight + padding * 2
                ColumnLayout {
                    id: sliders
                    width: parent.width; spacing: M3Tokens.dp(2)
                    M3Slider { Layout.fillWidth: true; showValue: true
                               icon: SystemServices.muted ? "volume_off" : "volume_up"
                               value: SystemServices.volumePercent
                               onMoved: SystemServices.setVolumePercent(value) }
                    M3Slider { Layout.fillWidth: true; showValue: true; visible: SystemServices.brightnessAvailable
                               icon: "brightness_6"; from: 1
                               value: SystemServices.brightnessPercent
                               onMoved: SystemServices.setBrightnessPercent(value) }
                }
            }

            M3Card {
                visible: !!SystemServices.battery
                Layout.fillWidth: true
                implicitHeight: bat.implicitHeight + padding * 2
                RowLayout {
                    id: bat
                    width: parent.width; spacing: M3Tokens.dp(10)
                    M3Icon { name: SystemServices.batteryIcon(); size: M3Tokens.dp(24)
                             color: (!SystemServices.charging && SystemServices.batteryPercent < 0.15) ? M3Theme.error : M3Theme.primaryText }
                    M3Text { Layout.fillWidth: true; type: "title"
                             text: "Battery " + Math.round(SystemServices.batteryPercent * 100) + "%" }
                    M3Text { muted: true; text: SystemServices.charging ? "Charging" : "On battery"; elide: Text.ElideNone }
                }
            }

            M3Card {
                Layout.fillWidth: true
                implicitHeight: notif.implicitHeight + padding * 2
                RowLayout {
                    id: notif
                    width: parent.width; spacing: M3Tokens.dp(10)
                    M3Icon { name: ConfigProvider.dnd ? "notifications_off" : "notifications_none"; size: M3Tokens.dp(24)
                             color: M3Theme.fgMuted }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        M3Text { Layout.fillWidth: true; text: "Notifications"; type: "title" }
                        M3Text { Layout.fillWidth: true; muted: true
                                 text: ConfigProvider.dnd ? "Do not disturb is on" : "No new notifications" }
                    }
                }
            }
        }
    }
}
