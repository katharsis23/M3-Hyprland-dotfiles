pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // UI text font. "JetBrainsMono Nerd Font" carries all Nerd Font glyphs so
    // icon fallbacks render everywhere. Everything in the shell reads `family`
    // (via M3Text), so changing it here restyles the whole UI at once.
    readonly property string family: "JetBrainsMono Nerd Font"
    readonly property string iconFamily: "Material Symbols Rounded"
    // Nerd Font family used for glyph icons in the launcher / fallbacks.
    readonly property string nerdFamily: "JetBrainsMono Nerd Font"

    readonly property int displayLarge:   M3Tokens.dp(57)
    readonly property int headlineMedium: M3Tokens.dp(28)
    readonly property int titleLarge:     M3Tokens.dp(22)
    readonly property int titleMedium:    M3Tokens.dp(16)
    readonly property int bodyLarge:      M3Tokens.dp(16)
    readonly property int bodyMedium:     M3Tokens.dp(14)
    readonly property int labelLarge:     M3Tokens.dp(13)
    readonly property int labelSmall:     M3Tokens.dp(11)
}

