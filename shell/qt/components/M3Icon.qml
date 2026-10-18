import QtQuick
import "../theme"

Text {
    id: root
    property string name: ""
    property int size: M3Tokens.dp(20)

    text: name
    color: M3Theme.fg
    font.family: Typography.iconFamily
    font.pixelSize: size
    width: size; height: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
}
