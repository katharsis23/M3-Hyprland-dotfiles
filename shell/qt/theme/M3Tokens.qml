pragma Singleton
import QtQuick
import Quickshell
import "../core"

// Every size in the shell goes through dp() so the whole UI scales with
// ConfigProvider.uiScale (Wayland fractional scaling is handled by Qt itself).
Singleton {
    readonly property real scale: Math.max(0.75, Math.min(1.75, ConfigProvider.uiScale))
    function dp(n) { return Math.round(n * scale) }

    readonly property int spaceXs: dp(4)
    readonly property int spaceSm: dp(8)
    readonly property int spaceMd: dp(12)
    readonly property int spaceLg: dp(16)
    readonly property int spaceXl: dp(24)

    readonly property int cornerRadiusXs: dp(4)
    readonly property int cornerRadiusSm: dp(8)
    readonly property int cornerRadiusMd: dp(12)
    readonly property int cornerRadiusLg: dp(16)
    readonly property int cornerRadiusXl: dp(28)
    readonly property int cornerRadiusFull: 999

    // motion (all 0 when animations are disabled)
    readonly property bool motion: ConfigProvider.animations
    readonly property int durationShort:  motion ? 150 : 0
    readonly property int durationMedium: motion ? 260 : 0
    readonly property int durationLong:   motion ? 420 : 0
    readonly property int easing: Easing.OutCubic

    // bar metrics shared by the bar and the overlays that sit next to it
    readonly property bool barFloating: ConfigProvider.barMode === "float"
    readonly property int barThickness: dp(barFloating ? 42 : 46)
    readonly property int barGap: barFloating ? dp(6) : 0
    readonly property int barEdgeInset: barThickness + barGap * 2 + dp(6)
}
