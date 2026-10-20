import QtQuick
import QtQuick.Layouts
import "../theme"
import "../core"

// Read-only image picker over the backend's fs.* methods. The backend lists only
// directories and images; the chosen file is returned as an absolute `path`.
Item {
    id: root
    signal picked(string path)
    signal cancelled()

    property string currentPath: ""
    property var entries: []
    property bool loading: false
    property string error: ""
    property int _token: 0                       // drops out-of-order responses

    function open(path) {
        const t = ++_token
        loading = true; error = ""
        AiBridge.fsList(path, (r, ok, err) => {
            if (t !== root._token) return
            root.loading = false
            if (!r) { root.error = err || "Cannot open folder"; return }
            root.currentPath = path
            root.entries = r.entries || []
            list.positionViewAtBeginning()
        })
    }
    function goHome() {
        AiBridge.fsHome((r) => {
            if (r) root.open(r.cwd || r.home || "")
            else root.error = "Backend unavailable"
        })
    }
    function goUp() {
        if (root.currentPath === "") return
        AiBridge.fsParent(root.currentPath, (r) => { if (r && r.path) root.open(r.path) })
    }
    Component.onCompleted: goHome()

    ColumnLayout {
        anchors.fill: parent
        spacing: M3Tokens.spaceSm

        RowLayout {
            Layout.fillWidth: true
            spacing: M3Tokens.spaceXs
            M3IconButton { icon: "arrow_upward"; size: M3Tokens.dp(32); tooltip: "Up"; onClicked: root.goUp() }
            M3IconButton { icon: "home"; size: M3Tokens.dp(32); tooltip: "Home"; onClicked: root.goHome() }
            M3Text {
                Layout.fillWidth: true; Layout.minimumWidth: 0
                text: root.currentPath; type: "caption"; muted: true
                elide: Text.ElideLeft
            }
            M3IconButton { icon: "close"; size: M3Tokens.dp(32); tooltip: "Cancel"; onClicked: root.cancelled() }
        }

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: M3Tokens.dp(2)
                model: root.entries
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: rowItem
                    required property var modelData
                    width: list.width
                    height: M3Tokens.dp(52)
                    radius: M3Tokens.cornerRadiusMd
                    color: hover.hovered ? M3Theme.surfaceContainerHigh : "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: M3Tokens.dp(8); rightMargin: M3Tokens.dp(8) }
                        spacing: M3Tokens.dp(10)
                        Item {
                            Layout.preferredWidth: M3Tokens.dp(36); Layout.preferredHeight: M3Tokens.dp(36)
                            M3Icon {
                                anchors.centerIn: parent
                                visible: rowItem.modelData.isDir
                                name: "folder"; size: M3Tokens.dp(26); color: M3Theme.primaryText
                            }
                            Image {
                                anchors.fill: parent
                                visible: !rowItem.modelData.isDir && status === Image.Ready
                                source: rowItem.modelData.isDir ? "" : (rowItem.modelData.url || "")
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(M3Tokens.dp(72), M3Tokens.dp(72))
                            }
                        }
                        M3Text {
                            Layout.fillWidth: true; Layout.minimumWidth: 0
                            text: rowItem.modelData.name
                        }
                    }
                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: rowItem.modelData.isDir ? root.open(rowItem.modelData.path)
                                                           : root.picked(rowItem.modelData.path)
                    }
                }
            }
            M3Text {
                anchors.centerIn: parent
                visible: !root.loading && root.entries.length === 0 && root.error === ""
                text: "No images or folders here"; muted: true
            }
            M3Text {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                visible: root.error !== ""
                text: root.error; color: M3Theme.error
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            }
        }
    }
}
