import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../core"

// Month grid that fills whatever width it is given (7 equal columns).
ColumnLayout {
    id: root
    property date shown: new Date()
    property date today: new Date()
    readonly property int firstDow: (new Date(shown.getFullYear(), shown.getMonth(), 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
    spacing: M3Tokens.dp(6)
    implicitWidth: M3Tokens.dp(7 * 40)

    function prevMonth() { shown = new Date(shown.getFullYear(), shown.getMonth() - 1, 1) }
    function nextMonth() { shown = new Date(shown.getFullYear(), shown.getMonth() + 1, 1) }
    function goToday()   { today = new Date(); shown = new Date() }
    Connections { target: ConfigProvider
        function onCalendarOpenChanged() { if (ConfigProvider.calendarOpen) root.goToday() } }

    RowLayout {
        Layout.fillWidth: true
        M3IconButton { icon: "chevron_left"; size: M3Tokens.dp(32); onClicked: root.prevMonth() }
        M3Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                 text: Qt.formatDate(root.shown, "MMMM yyyy"); type: "title" }
        M3IconButton { icon: "today"; size: M3Tokens.dp(32); onClicked: root.goToday() }
        M3IconButton { icon: "chevron_right"; size: M3Tokens.dp(32); onClicked: root.nextMonth() }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7; rowSpacing: 0; columnSpacing: 0
        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]
            delegate: M3Text {
                required property string modelData
                Layout.fillWidth: true; Layout.preferredWidth: 1
                horizontalAlignment: Text.AlignHCenter; height: M3Tokens.dp(24)
                text: modelData; type: "caption"; muted: true
            }
        }
        Repeater {
            model: 42
            delegate: Item {
                id: cell
                required property int index
                readonly property int day: index - root.firstDow + 1
                readonly property bool valid: day >= 1 && day <= root.daysInMonth
                readonly property bool isToday: valid && day === root.today.getDate()
                    && root.shown.getMonth() === root.today.getMonth()
                    && root.shown.getFullYear() === root.today.getFullYear()
                Layout.fillWidth: true; Layout.preferredWidth: 1
                implicitHeight: M3Tokens.dp(36)
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height); height: width; radius: width / 2
                    color: cell.isToday ? M3Theme.primary
                         : (cell.valid && hover.hovered ? M3Theme.surfaceContainerHighest : "transparent")
                    Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }
                    M3Text {
                        anchors.centerIn: parent; visible: cell.valid; text: cell.day
                        elide: Text.ElideNone
                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                        color: cell.isToday ? M3Theme.primaryFg : M3Theme.fg
                    }
                }
                HoverHandler { id: hover }
            }
        }
    }
}
