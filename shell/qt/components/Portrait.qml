import QtQuick
import QtQuick.Effects
import "../theme"

// Round avatar: shows the portrait image when one resolves, otherwise the emoji
// centred on primaryContainer. `source` may be a file:// URL or an absolute path.
Item {
    id: root
    property string source: ""
    property string emoji: "🙂"
    property int size: M3Tokens.dp(40)

    implicitWidth: size; implicitHeight: size
    width: size; height: size

    readonly property string _url: source === "" ? ""
        : (source.startsWith("/") ? "file://" + source : source)
    readonly property bool hasImage: _url !== "" && img.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: M3Theme.primaryContainer
    }

    Image {
        id: img
        anchors.fill: parent
        source: root._url
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        visible: root.hasImage
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
        }
    }
    Item {                                       // circular alpha mask for the image
        id: mask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: width / 2 }
    }

    M3Text {
        anchors.centerIn: parent
        visible: !root.hasImage
        text: root.emoji
        elide: Text.ElideNone
        font.pixelSize: Math.round(root.size * 0.5)
    }
}
