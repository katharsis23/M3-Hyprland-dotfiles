pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string family: "Roboto"
    readonly property string iconFamily: "Material Symbols Rounded"

    readonly property int displayLarge:   M3Tokens.dp(57)
    readonly property int headlineMedium: M3Tokens.dp(28)
    readonly property int titleLarge:     M3Tokens.dp(22)
    readonly property int titleMedium:    M3Tokens.dp(16)
    readonly property int bodyLarge:      M3Tokens.dp(16)
    readonly property int bodyMedium:     M3Tokens.dp(14)
    readonly property int labelLarge:     M3Tokens.dp(13)
    readonly property int labelSmall:     M3Tokens.dp(11)
}
