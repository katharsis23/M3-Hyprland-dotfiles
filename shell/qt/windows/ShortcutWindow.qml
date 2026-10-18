import QtQuick
import QtQuick.Layouts
import "../components"
import "../theme"
import "../core"

M3Dialog {
    id: dlg
    title: "Keyboard shortcuts"; icon: "keyboard"
    onCloseRequested: ConfigProvider.shortcutsOpen = false
    onOpenChanged: if (open) { HyprlandIPC.reloadBinds(); search.text = ""; cat = "All"; search.forceActiveFocus() }

    property string cat: "All"

    // Hyprland modmask bits: SHIFT=1 CTRL=4 ALT=8 SUPER=64
    function mods(mask) {
        const p = []
        if (mask & 64) p.push("SUPER"); if (mask & 4) p.push("CTRL")
        if (mask & 8) p.push("ALT");   if (mask & 1) p.push("SHIFT")
        return p
    }
    function keyLabel(k, code) { return (k && k !== "") ? k.toUpperCase() : (code > 0 ? "code:" + code : "?") }
    function pretty(b) { return mods(b.modmask).concat([keyLabel(b.key, b.keycode)]).join(" + ") }
    function category(d) {
        if (d.indexOf("workspace") !== -1) return "Workspaces"
        if (d === "movefocus" || d === "cyclenext" || d === "focuswindow") return "Navigation"
        if (d === "exec" || d === "spawn") return "Launchers"
        if (["killactive", "togglefloating", "fullscreen", "movewindow", "resizeactive", "pin"].indexOf(d) >= 0) return "Window"
        return "Other"
    }

    readonly property var rows: {
        const out = [], binds = HyprlandIPC.binds
        for (let i = 0; i < binds.length; i++) {
            const b = binds[i]
            if (b.keycode === 0 && (!b.key || b.key === "")) continue
            out.push({ cat: category(b.dispatcher), keys: pretty(b),
                       desc: b.description !== "" ? b.description : (b.dispatcher + (b.arg ? " " + b.arg : "")) })
        }
        return out.sort((a, b) => a.cat.localeCompare(b.cat))
    }
    readonly property var cats: ["All"].concat(rows.map(r => r.cat).filter((c, i, a) => a.indexOf(c) === i))
    readonly property var filtered: rows.filter(r =>
        (cat === "All" || r.cat === cat)
        && (r.keys + " " + r.desc + " " + r.cat).toLowerCase().includes(search.text.toLowerCase()))

    ColumnLayout {
        anchors.fill: parent
        spacing: M3Tokens.dp(10)

        RowLayout {
            Layout.fillWidth: true
            M3TextField { id: search; Layout.fillWidth: true; icon: "search"; placeholderText: "Search shortcuts…" }
            M3IconButton { icon: "refresh"; tooltip: "Reload"; onClicked: HyprlandIPC.reloadBinds() }
        }
        Flow {
            Layout.fillWidth: true
            spacing: M3Tokens.dp(6)
            Repeater {
                model: dlg.cats
                delegate: M3Button {
                    required property string modelData
                    text: modelData; compact: true
                    variant: dlg.cat === modelData ? "filled" : "outlined"
                    onClicked: dlg.cat = modelData
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: M3Tokens.dp(6)
            model: dlg.filtered
            section.property: "cat"
            section.delegate: M3Text {
                required property string section
                width: list.width; height: M3Tokens.dp(34)
                verticalAlignment: Text.AlignBottom
                text: section; type: "label"; color: M3Theme.primaryText
            }
            delegate: Rectangle {
                id: row
                required property var modelData
                width: list.width
                implicitHeight: g.implicitHeight + M3Tokens.dp(20)
                height: implicitHeight
                radius: M3Tokens.cornerRadiusMd
                color: hov.hovered ? M3Theme.surfaceContainerHighest : M3Theme.surfaceContainerHigh
                Behavior on color { ColorAnimation { duration: M3Tokens.durationShort } }
                GridLayout {
                    id: g
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: M3Tokens.dp(14); rightMargin: M3Tokens.dp(14) }
                    columns: row.width > M3Tokens.dp(520) ? 2 : 1
                    columnSpacing: M3Tokens.dp(12); rowSpacing: M3Tokens.dp(6)
                    M3Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: row.modelData.desc }
                    RowLayout {
                        spacing: M3Tokens.dp(4)
                        Repeater {
                            model: row.modelData.keys.split(" + ")
                            delegate: Rectangle {
                                required property string modelData
                                implicitWidth: kt.implicitWidth + M3Tokens.dp(16); implicitHeight: M3Tokens.dp(26)
                                radius: M3Tokens.cornerRadiusSm
                                color: M3Theme.secondaryContainer
                                M3Text { id: kt; anchors.centerIn: parent; text: parent.modelData
                                         type: "caption"; elide: Text.ElideNone; color: M3Theme.secondaryContainerFg }
                            }
                        }
                    }
                }
                HoverHandler { id: hov }
            }
            M3Text { parent: list; anchors.centerIn: list; visible: dlg.filtered.length === 0; muted: true
                     text: HyprlandIPC.binds.length === 0 ? "No keybinds found (is hyprctl available?)" : "No shortcuts match" }
        }
    }
}
