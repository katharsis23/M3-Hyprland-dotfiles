import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../theme/Palette.js" as Palette
import "../core"

// Settings dialog. Wide: left navigation rail. Narrow: navigation becomes a top row.
M3Dialog {
    id: dlg
    title: "Settings"; icon: "tune"
    onCloseRequested: ConfigProvider.settingsOpen = false

    readonly property bool wide: width > M3Tokens.dp(620)
    property int page: 0
    readonly property var pages: [
        { label: "Appearance", icon: "palette" }, { label: "Bar", icon: "view_agenda" },
        { label: "Behavior", icon: "toggle_on" }, { label: "Assistant", icon: "smart_toy" } ]
    readonly property var seeds: ["#6750A4", "#7D5260", "#B3261E", "#006A6A", "#0061A4", "#386A20", "#7D5700", "#625B71"]

    component SectionLabel: M3Text { type: "label"; color: M3Theme.primaryText; Layout.topMargin: M3Tokens.dp(6) }
    component SwitchRow: RowLayout {
        id: sr
        property string label: ""
        property string hint: ""
        property alias checked: sw.checked
        signal toggled(bool v)
        Layout.fillWidth: true
        spacing: M3Tokens.dp(12)
        ColumnLayout {
            Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 0
            M3Text { Layout.fillWidth: true; text: sr.label; type: "title"; font.pixelSize: Typography.bodyLarge }
            M3Text { Layout.fillWidth: true; visible: sr.hint !== ""; text: sr.hint; type: "caption"; muted: true }
        }
        M3Switch { id: sw; onToggled: (v) => sr.toggled(v) }
    }

    GridLayout {
        anchors.fill: parent
        columns: dlg.wide ? 2 : 1
        columnSpacing: M3Tokens.dp(16); rowSpacing: M3Tokens.dp(10)

        // ---- navigation -------------------------------------------------
        GridLayout {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: !dlg.wide
            Layout.preferredWidth: dlg.wide ? M3Tokens.dp(170) : -1
            columns: dlg.wide ? 1 : dlg.pages.length
            columnSpacing: M3Tokens.dp(6); rowSpacing: M3Tokens.dp(4)
            Repeater {
                model: dlg.pages
                delegate: Rectangle {
                    id: nav
                    required property int index
                    required property var modelData
                    readonly property bool sel: dlg.page === index
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    implicitHeight: M3Tokens.dp(44)
                    radius: M3Tokens.cornerRadiusFull
                    color: sel ? M3Theme.secondaryContainer : (hov.hovered ? M3Theme.surfaceContainerHighest : "transparent")
                    Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: M3Tokens.dp(14); rightMargin: M3Tokens.dp(10) }
                        spacing: M3Tokens.dp(10)
                        Item { Layout.fillWidth: !dlg.wide && dlg.width < M3Tokens.dp(480) }
                        M3Icon { name: nav.modelData.icon; size: M3Tokens.dp(20)
                                 color: nav.sel ? M3Theme.secondaryContainerFg : M3Theme.fgMuted }
                        M3Text { visible: dlg.wide || dlg.width >= M3Tokens.dp(480); Layout.fillWidth: true
                                 text: nav.modelData.label; type: "label"
                                 color: nav.sel ? M3Theme.secondaryContainerFg : M3Theme.fg }
                        Item { Layout.fillWidth: !dlg.wide && dlg.width < M3Tokens.dp(480) }
                    }
                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: dlg.page = nav.index }
                }
            }
        }

        // ---- pages ------------------------------------------------------
        M3Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            contentWidth: width; contentHeight: pageCol.implicitHeight + M3Tokens.dp(8)

            ColumnLayout {
                id: pageCol
                width: parent.width - M3Tokens.dp(8)
                spacing: M3Tokens.dp(10)

                // Appearance
                ColumnLayout {
                    visible: dlg.page === 0
                    Layout.fillWidth: true; spacing: M3Tokens.dp(10)
                    SectionLabel { text: "Theme" }
                    M3Segmented {
                        Layout.fillWidth: true
                        options: [{ value: true, label: "Dark", icon: "dark_mode" }, { value: false, label: "Light", icon: "light_mode" }]
                        current: ConfigProvider.darkMode
                        onPicked: (v) => ConfigProvider.darkMode = v
                    }
                    SectionLabel { text: "Preview" }
                    RowLayout {
                        Layout.fillWidth: true; spacing: M3Tokens.dp(6)
                        Repeater {
                            model: [
                                { bg: M3Theme.primary, fg: M3Theme.primaryFg },
                                { bg: M3Theme.secondaryContainer, fg: M3Theme.secondaryContainerFg },
                                { bg: M3Theme.tertiary, fg: M3Theme.tertiaryFg },
                                { bg: M3Theme.surfaceContainerHighest, fg: M3Theme.fg },
                                { bg: M3Theme.errorContainer, fg: M3Theme.errorContainerFg } ]
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: M3Tokens.dp(46)
                                radius: M3Tokens.cornerRadiusMd; color: modelData.bg
                                border.width: 1; border.color: M3Theme.outlineVariant
                                M3Text { anchors.centerIn: parent; text: "Aa"; type: "title"; color: parent.modelData.fg; elide: Text.ElideNone }
                            }
                        }
                    }
                    SectionLabel { text: "Seed colour" }
                    Flow {
                        Layout.fillWidth: true; spacing: M3Tokens.dp(10)
                        Repeater {
                            model: dlg.seeds
                            delegate: Rectangle {
                                id: sw
                                required property string modelData
                                readonly property bool current: Qt.colorEqual(ConfigProvider.seedColor, modelData)
                                width: M3Tokens.dp(40); height: width; radius: width / 2
                                color: modelData
                                border.width: current ? 3 : 1
                                border.color: current ? M3Theme.fg : M3Theme.outlineVariant
                                scale: swHover.hovered ? 1.08 : 1
                                Behavior on scale { NumberAnimation { duration: M3Tokens.durationShort } }
                                M3Icon { anchors.centerIn: parent; visible: sw.current; name: "check"; size: M3Tokens.dp(20)
                                         color: Palette.contrast("#ffffff", sw.modelData) > Palette.contrast("#000000", sw.modelData) ? "#ffffff" : "#000000" }
                                HoverHandler { id: swHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: ConfigProvider.seedColor = sw.modelData }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: M3Tokens.dp(8)
                        M3TextField { id: hex; Layout.fillWidth: true; Layout.minimumWidth: 0; icon: "colorize"
                                      placeholderText: "Custom #RRGGBB"
                                      onAccepted: apply.clicked() }
                        M3Button { id: apply; text: "Apply"; variant: "tonal"
                                   onClicked: { const c = Palette.parseHex(hex.text)
                                                if (c) ConfigProvider.seedColor = "#" + hex.text.replace("#", "").slice(-6) } }
                    }
                    SectionLabel { text: "Interface scale" }
                    M3Slider {
                        id: scaleSlider
                        Layout.fillWidth: true; from: 75; to: 175; stepSize: 5; showValue: true; icon: "zoom_in"
                        onPressedChanged: if (!pressed) ConfigProvider.uiScale = value / 100
                        Binding on value { when: !scaleSlider.pressed; value: ConfigProvider.uiScale * 100 }
                    }
                }

                // Bar
                ColumnLayout {
                    visible: dlg.page === 1
                    Layout.fillWidth: true; spacing: M3Tokens.dp(10)
                    SectionLabel { text: "Position" }
                    M3Segmented {
                        Layout.fillWidth: true
                        options: [{ value: "top", label: "Top", icon: "align_vertical_top" },
                                  { value: "bottom", label: "Bottom", icon: "align_vertical_bottom" },
                                  { value: "left", label: "Left", icon: "align_horizontal_left" },
                                  { value: "right", label: "Right", icon: "align_horizontal_right" }]
                        current: ConfigProvider.barPosition
                        onPicked: (v) => ConfigProvider.barPosition = v
                    }
                    SectionLabel { text: "Style" }
                    M3Segmented {
                        Layout.fillWidth: true
                        options: [{ value: "float", label: "Float" }, { value: "hug", label: "Hug" }]
                        current: ConfigProvider.barMode
                        onPicked: (v) => ConfigProvider.barMode = v
                    }
                    M3Text { Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone; type: "caption"; muted: true
                             text: "Float shows separate rounded islands; Hug is one strip along the screen edge. Modules drop out automatically on short bars." }
                }

                // Behavior
                ColumnLayout {
                    visible: dlg.page === 2
                    Layout.fillWidth: true; spacing: M3Tokens.dp(14)
                    SwitchRow { label: "Show seconds"; checked: ConfigProvider.clockSeconds; onToggled: (v) => ConfigProvider.clockSeconds = v }
                    SwitchRow { label: "24-hour clock"; checked: ConfigProvider.clock24h; onToggled: (v) => ConfigProvider.clock24h = v }
                    SwitchRow { label: "Animations"; hint: "Turn off for a snappier, calmer shell"
                                checked: ConfigProvider.animations; onToggled: (v) => ConfigProvider.animations = v }
                    SwitchRow { label: "Glass surfaces"; hint: "Translucent panels (blur needs a Hyprland layerrule)"
                                checked: ConfigProvider.blurEnabled; onToggled: (v) => ConfigProvider.blurEnabled = v }
                    SwitchRow { label: "Desktop clock"; checked: ConfigProvider.desktopClock; onToggled: (v) => ConfigProvider.desktopClock = v }
                }

                // Assistant
                ColumnLayout {
                    visible: dlg.page === 3
                    Layout.fillWidth: true; spacing: M3Tokens.dp(10)
                    SectionLabel { text: "Ollama model" }
                    M3TextField { Layout.fillWidth: true; icon: "smart_toy"; text: ConfigProvider.aiModel
                                  onEditingFinished: if (text.trim() !== "") ConfigProvider.aiModel = text.trim() }
                    M3Text { Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone; type: "caption"; muted: true
                             text: "Talks to http://localhost:11434 (Ollama). Pull the model first: ollama pull " + ConfigProvider.aiModel }
                }

                M3Button { Layout.topMargin: M3Tokens.dp(10); text: "Reset to defaults"; icon: "restart_alt"
                           onClicked: ConfigProvider.resetDefaults() }
            }
        }
    }
}
