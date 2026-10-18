//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "windows"

ShellRoot {
    // One bar / desktop clock / overlay layer per monitor.
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: scope
            required property var modelData
            TopBar { screen: scope.modelData }
            DesktopClock { screen: scope.modelData }
            OverlayLayer { screen: scope.modelData }
        }
    }

    // qs ipc call shell toggleSidebar   (bind these in hyprland.conf)
    IpcHandler {
        target: "shell"
        function toggleSidebar(): void { ConfigProvider.toggleSidebar("") }
        function toggleQuickSettings(): void { ConfigProvider.toggleQuickSettings("") }
        function toggleCalendar(): void { ConfigProvider.toggleCalendar("") }
        function toggleSettings(): void { ConfigProvider.toggleSettings("") }
        function toggleShortcuts(): void { ConfigProvider.toggleShortcuts("") }
        function closeAll(): void { ConfigProvider.closeAll() }
    }
}
