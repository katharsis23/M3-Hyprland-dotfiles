import QtQuick
import "../theme"

// The ONLY text element used in the shell. Colour defaults to the theme
// foreground, so a label can never fall back to Qt's default black.
Text {
    id: root
    property string type: "body"        // display | headline | title | body | label | caption
    property bool muted: false

    color: muted ? M3Theme.fgMuted : M3Theme.fg
    font.family: Typography.family
    font.pixelSize: type === "display" ? Typography.displayLarge
                  : type === "headline" ? Typography.headlineMedium
                  : type === "title" ? Typography.titleMedium
                  : type === "label" ? Typography.labelLarge
                  : type === "caption" ? Typography.labelSmall
                  : Typography.bodyMedium
    font.weight: (type === "headline" || type === "title" || type === "label") ? Font.Medium
               : type === "display" ? Font.Light : Font.Normal
    textFormat: Text.PlainText          // never interpret remote/AI text as rich text
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
