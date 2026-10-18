import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../components"
import "../theme"
import "../core"

// Custom in-shell application launcher, fully integrated with the M3 theme.
// A centred spotlight-style card: search field + keyboard-navigable results.
// Fed by LauncherService (scans XDG .desktop files). Built on QtQuick, so it
// shares fonts, colours and motion with the rest of the shell — no fuzzel.
PanelWindow {
    id: win
    readonly property string screenName: screen ? screen.name : ""
    readonly property bool mine: ConfigProvider.overlayScreen === screenName

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: LauncherService.open && mine
    WlrLayershell.namespace: "m3shell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (LauncherService.open && mine)
                                 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int selected: 0
    readonly property int cardW: Math.min(M3Tokens.dp(640), width - M3Tokens.dp(80))
    readonly property int maxResults: 8

    function move(delta) {
        const n = Math.min(LauncherService.results.length, win.maxResults)
        if (n === 0) return
        win.selected = (win.selected + delta + n) % n
    }
    function activate() {
        const r = LauncherService.results[win.selected]
        if (r) LauncherService.launch(r)
    }

    onVisibleChanged: if (visible) { win.selected = 0; field.text = ""; field.forceActiveFocus() }
    Connections {
        target: LauncherService
        function onQueryChanged() { win.selected = 0 }
    }

    FocusScope {
        anchors.fill: parent
        focus: win.visible

        Keys.onEscapePressed: LauncherService.hide()
        Keys.onDownPressed: win.move(1)
        Keys.onUpPressed: win.move(-1)
        Keys.onReturnPressed: win.activate()
        Keys.onEnterPressed: win.activate()

        // dim backdrop
        Rectangle {
            anchors.fill: parent
            color: M3Theme.scrim
            opacity: win.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: M3Tokens.durationMedium } }
            MouseArea { anchors.fill: parent; onClicked: LauncherService.hide() }
        }

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.16)
            width: win.cardW
            height: col.implicitHeight + M3Tokens.dp(24)
            radius: M3Tokens.cornerRadiusXl
            color: M3Theme.surfaceGlass
            border.width: 1
            border.color: M3Theme.alpha(M3Theme.outline, 0.35)
            // swallow clicks so they don't close the launcher
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            Rectangle {                              // soft shadow
                z: -1
                anchors { fill: parent; margins: -1; topMargin: 3; bottomMargin: -4 }
                radius: parent.radius + 2
                color: M3Theme.shadow
            }

            ColumnLayout {
                id: col
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: M3Tokens.dp(12) }
                spacing: M3Tokens.dp(8)

                // Search field
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: M3Tokens.dp(52)
                    radius: M3Tokens.cornerRadiusFull
                    color: M3Theme.surfaceContainerHighest
                    border.width: field.activeFocus ? 2 : 1
                    border.color: field.activeFocus ? M3Theme.primary : M3Theme.outlineVariant

                    M3Icon {
                        anchors { left: parent.left; leftMargin: M3Tokens.dp(16); verticalCenter: parent.verticalCenter }
                        name: "search"; size: M3Tokens.dp(22); color: M3Theme.fgMuted
                    }
                    TextInput {
                        id: field
                        anchors { fill: parent; leftMargin: M3Tokens.dp(48); rightMargin: M3Tokens.dp(16) }
                        verticalAlignment: TextInput.AlignVCenter
                        color: M3Theme.fg
                        selectionColor: M3Theme.primary
                        selectedTextColor: M3Theme.primaryFg
                        font.family: Typography.family
                        font.pixelSize: Typography.bodyLarge
                        clip: true
                        onTextChanged: LauncherService.query = text
                        Keys.onDownPressed: win.move(1)
                        Keys.onUpPressed: win.move(-1)
                        Keys.onReturnPressed: win.activate()
                        Keys.onEnterPressed: win.activate()
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: field.text === ""
                            text: "Search applications…"
                            color: M3Theme.fgMuted
                            font.family: Typography.family
                            font.pixelSize: Typography.bodyLarge
                        }
                    }
                }

                // Results
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, M3Tokens.dp(win.maxResults * 52))
                    implicitHeight: contentHeight
                    clip: true
                    model: LauncherService.results
                    currentIndex: win.selected
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: M3Tokens.dp(52)
                        radius: M3Tokens.cornerRadiusMd
                        color: index === win.selected ? M3Theme.secondaryContainer
                             : (rhover.hovered ? M3Theme.surfaceContainerHigh : "transparent")
                        Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }

                        // Desktop icon: resolve the .desktop Icon= name to a
                        // theme pixmap; fall back to a Material glyph.
                        IconImage {
                            id: rowIcon
                            anchors { left: parent.left; leftMargin: M3Tokens.dp(12); verticalCenter: parent.verticalCenter }
                            implicitSize: M3Tokens.dp(28)
                            source: row.modelData.icon !== "" ? Quickshell.iconPath(row.modelData.icon, true) : ""
                            visible: source !== "" && status === Image.Ready
                        }
                        M3Icon {
                            anchors { left: parent.left; leftMargin: M3Tokens.dp(14); verticalCenter: parent.verticalCenter }
                            visible: !rowIcon.visible
                            name: "apps"; size: M3Tokens.dp(24)
                            color: index === win.selected ? M3Theme.secondaryContainerFg : M3Theme.fgMuted
                        }
                        ColumnLayout {
                            anchors { left: parent.left; leftMargin: M3Tokens.dp(52); right: parent.right; rightMargin: M3Tokens.dp(12); verticalCenter: parent.verticalCenter }
                            spacing: 0
                            M3Text {
                                Layout.fillWidth: true; text: row.modelData.name; type: "title"
                                color: index === win.selected ? M3Theme.secondaryContainerFg : M3Theme.fg
                                elide: Text.ElideRight
                            }
                            M3Text {
                                Layout.fillWidth: true; visible: row.modelData.generic !== ""
                                text: row.modelData.generic; type: "caption"
                                color: index === win.selected ? M3Theme.secondaryContainerFg : M3Theme.fgMuted
                                elide: Text.ElideRight
                            }
                        }
                        HoverHandler { id: rhover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { win.selected = index; win.activate() } }
                    }

                    M3Text {
                        anchors.centerIn: parent
                        visible: LauncherService.results.length === 0
                        text: LauncherService.query === "" ? "Type to search apps…" : "No matches for “" + LauncherService.query + "”"
                        muted: true
                    }
                }

                // Footer hint
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: M3Tokens.dp(2)
                    M3Text { text: "↑↓ navigate"; type: "caption"; muted: true }
                    M3Text { text: "⏎ launch"; type: "caption"; muted: true }
                    M3Text { text: "esc close"; type: "caption"; muted: true }
                    Item { Layout.fillWidth: true }
                    M3Text { text: LauncherService.results.length + " results"; type: "caption"; muted: true }
                }
            }
        }
    }
}
