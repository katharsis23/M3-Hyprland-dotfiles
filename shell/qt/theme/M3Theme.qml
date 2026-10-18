pragma Singleton
import QtQuick
import Quickshell
import "../core"
import "Palette.js" as Palette

// Material 3 colour roles.
//
// All colours come from ONE pure-JS call (Palette.build) that returns validated
// "#rrggbb" strings with every foreground chosen by measured WCAG contrast
// (>= 4.5:1, tested for 17 seeds x light/dark). There are deliberately NO
// properties called on*: names like `onSurface` look like signal handlers to
// QML and were the source of the "black text on dark theme" bug. Foreground
// roles use a "...Fg" suffix instead (onSurface -> fg, onSurfaceVariant -> fgMuted).
Singleton {
    readonly property bool dark: ConfigProvider.darkMode
    readonly property var p: Palette.build("" + ConfigProvider.seedColor, ConfigProvider.darkMode)

    // surfaces
    readonly property color surface:                 p.surface
    readonly property color surfaceContainerLowest:  p.surfaceContainerLowest
    readonly property color surfaceContainerLow:     p.surfaceContainerLow
    readonly property color surfaceContainer:        p.surfaceContainer
    readonly property color surfaceContainerHigh:    p.surfaceContainerHigh
    readonly property color surfaceContainerHighest: p.surfaceContainerHighest
    // text / icons on surfaces
    readonly property color fg:        p.fg
    readonly property color fgMuted:   p.fgMuted
    readonly property color outline:        p.outline
    readonly property color outlineVariant: p.outlineVariant
    // accents (+ their foregrounds)
    readonly property color primary:              p.primary
    readonly property color primaryFg:            p.primaryFg
    readonly property color primaryContainer:     p.primaryContainer
    readonly property color primaryContainerFg:   p.primaryContainerFg
    readonly property color primaryText:          p.primaryText      // accent used AS text on surfaces
    readonly property color secondary:            p.secondary
    readonly property color secondaryFg:          p.secondaryFg
    readonly property color secondaryContainer:   p.secondaryContainer
    readonly property color secondaryContainerFg: p.secondaryContainerFg
    readonly property color tertiary:             p.tertiary
    readonly property color tertiaryFg:           p.tertiaryFg
    readonly property color tertiaryContainer:    p.tertiaryContainer
    readonly property color tertiaryContainerFg:  p.tertiaryContainerFg
    readonly property color error:                p.error
    readonly property color errorFg:              p.errorFg
    readonly property color errorContainer:       p.errorContainer
    readonly property color errorContainerFg:     p.errorContainerFg

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // translucent "glass" layer; opaque when blur/glass is switched off
    readonly property color surfaceGlass:
        alpha(surfaceContainer, ConfigProvider.blurEnabled ? (dark ? 0.80 : 0.88) : 1.0)
    readonly property color scrim: Qt.rgba(0, 0, 0, dark ? 0.50 : 0.32)
    readonly property color shadow: Qt.rgba(0, 0, 0, dark ? 0.38 : 0.16)
}
