import QtQuick
import QtQuick.Shapes
import "../components"
import "../theme"

// 270-degree ring gauge. value: 0..1
Item {
    id: root
    property real value: 0
    property string label: ""
    property string detail: ""
    property color accent: M3Theme.primary
    readonly property real stroke: M3Tokens.dp(9)
    implicitWidth: M3Tokens.dp(110); implicitHeight: M3Tokens.dp(110)

    Shape {
        anchors.fill: parent
        antialiasing: true
        layer.enabled: true; layer.samples: 4
        ShapePath {
            strokeColor: M3Theme.secondaryContainer; fillColor: "transparent"
            strokeWidth: root.stroke; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.width / 2 - root.stroke; radiusY: root.height / 2 - root.stroke
                startAngle: 135; sweepAngle: 270 }
        }
        ShapePath {
            strokeColor: root.value > 0.85 ? M3Theme.error : root.accent
            fillColor: "transparent"
            strokeWidth: root.stroke; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.width / 2 - root.stroke; radiusY: root.height / 2 - root.stroke
                startAngle: 135; sweepAngle: 270 * Math.max(0.001, Math.min(1, root.value))
                Behavior on sweepAngle { NumberAnimation { duration: M3Tokens.durationLong; easing.type: M3Tokens.easing } } }
        }
    }
    Column {
        anchors.centerIn: parent
        M3Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(root.value * 100) + "%"
                 type: "title"; elide: Text.ElideNone }
        M3Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.label
                 type: "caption"; muted: true; elide: Text.ElideNone }
    }
}
