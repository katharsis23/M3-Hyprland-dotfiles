import QtQuick
import QtQuick.Layouts
import "../theme"

M3Panel {
    id: dlg
    property string title: ""
    property string icon: ""
    default property alias body: holder.data
    signal closeRequested()

    ColumnLayout {
        anchors { fill: parent; margins: M3Tokens.dp(20) }
        spacing: M3Tokens.dp(14)
        RowLayout {
            Layout.fillWidth: true
            spacing: M3Tokens.dp(10)
            M3Icon { visible: dlg.icon !== ""; name: dlg.icon; size: M3Tokens.dp(26); color: M3Theme.primaryText }
            M3Text { Layout.fillWidth: true; text: dlg.title; type: "headline" }
            M3IconButton { icon: "close"; tooltip: "Close (Esc)"; onClicked: dlg.closeRequested() }
        }
        Item { id: holder; Layout.fillWidth: true; Layout.fillHeight: true }
    }
}
