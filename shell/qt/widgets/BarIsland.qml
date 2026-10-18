import QtQuick
import QtQuick.Layouts
import "../theme"

// One rounded "island" of the bar. Orientation/style are passed in explicitly.
Rectangle {
    id: isl
    property bool vertical: false
    property bool floating: true
    property int thickness: M3Tokens.barThickness
    default property alias items: grid.data

    readonly property int pad: M3Tokens.dp(4)
    readonly property int cross: thickness - (floating ? 0 : M3Tokens.dp(8))
    implicitWidth: vertical ? cross : grid.implicitWidth + pad * 2
    implicitHeight: vertical ? grid.implicitHeight + pad * 2 : cross
    color: floating ? M3Theme.surfaceGlass : "transparent"
    radius: floating ? M3Tokens.cornerRadiusFull : 0
    border.width: floating ? 1 : 0
    border.color: M3Theme.alpha(M3Theme.outline, 0.30)

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: isl.vertical ? 1 : 100
        rowSpacing: M3Tokens.dp(2); columnSpacing: M3Tokens.dp(2)
    }
}
