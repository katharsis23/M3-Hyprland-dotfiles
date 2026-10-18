pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth

// Live system services: audio (PipeWire), battery/power (UPower),
// networking (NetworkManager), and Bluetooth.
Singleton {
    id: root

    // ---- Audio (PipeWire) -------------------------------------------------
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property bool muted: audioSink && audioSink.audio ? audioSink.audio.muted : false

    // Volume normalized 0..1 (PwNodeAudio.volume is linear 0..1).
    readonly property real volume: audioSink && audioSink.audio ? audioSink.audio.volume : 0
    readonly property int volumePercent: Math.round(volume * 100)

    function setVolumePercent(p) {
        if (audioSink && audioSink.audio) {
            audioSink.audio.volume = Math.max(0, Math.min(1, p / 100))
        }
    }
    function toggleMute() {
        if (audioSink && audioSink.audio) audioSink.audio.muted = !audioSink.audio.muted
    }
    function volumeUp(step) {
        if (!step) step = 5
        // Absolute control avoids getting stuck because PipeWire reports async.
        setVolumePercent(volumePercent + step)
    }
    function volumeDown(step) {
        if (!step) step = 5
        setVolumePercent(volumePercent - step)
    }

    // ---- Battery / Power (UPower) ----------------------------------------
    readonly property var battery: UPower.displayDevice
    readonly property bool isOnBattery: UPower.onBattery
    readonly property real batteryPercent: battery ? battery.percentage : 1.0
    readonly property bool charging:
        battery ? (battery.state === UPowerDeviceState.Charging
                   || battery.state === UPowerDeviceState.PendingCharge
                   || battery.state === UPowerDeviceState.FullyCharged) : false

    // Map percentage to a Material Symbol name.
    function batteryIcon() {
        if (!battery) return "battery_unknown"
        if (charging) return "battery_charging_full"
        const p = batteryPercent
        if (p > 0.9) return "battery_full"
        if (p > 0.7) return "battery_6_bar"
        if (p > 0.5) return "battery_4_bar"
        if (p > 0.3) return "battery_2_bar"
        if (p > 0.15) return "battery_1_bar"
        return "battery_alert"
    }

    // ---- Networking -------------------------------------------------------
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool online: _online
    property bool _online: false

    function setWifiEnabled(on) { Networking.requestSetWifiEnabled(on) }
    function toggleWifi() { Networking.requestSetWifiEnabled(!Networking.wifiEnabled) }

    // Track connectivity via NetworkManager devices.
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: root._refreshOnline()
    }
    function _refreshOnline() {
        let any = false
        const devs = Networking.devices
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) { any = true; break }
        }
        root._online = any
    }

    // ---- Bluetooth --------------------------------------------------------
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: btAdapter ? btAdapter.enabled : false
    function toggleBluetooth() {
        if (btAdapter) btAdapter.enabled = !btAdapter.enabled
    }

    // ---- Brightness (brightnessctl; slider is hidden when unavailable) -----
    property int brightnessPercent: 100
    property bool brightnessAvailable: false
    Process {
        id: brightGet
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(",")
                const v = parseInt(f[3])
                if (f.length >= 4 && !isNaN(v)) { root.brightnessAvailable = true; root.brightnessPercent = v }
            }
        }
    }
    Process { id: brightSet }
    function setBrightnessPercent(p) {
        p = Math.max(1, Math.min(100, Math.round(p)))
        brightnessPercent = p
        brightSet.exec(["brightnessctl", "set", p + "%"])
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: brightGet.running = true }

    // ---- Night light (needs hyprsunset running) ----------------------------
    Process { id: sunset }
    function setNightLight(on) {
        sunset.exec(on ? ["hyprctl", "hyprsunset", "temperature", "4200"] : ["hyprctl", "hyprsunset", "identity"])
    }
}
