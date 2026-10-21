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
            Launcher { screen: scope.modelData }
        }
    }

    // qs ipc call shell toggleSidebar   (bind these in hyprland.conf)
    IpcHandler {
        target: "shell"
        function toggleSidebar(): void { ConfigProvider.toggleSidebar("") }
        function toggleAiSidebar(): void { ConfigProvider.toggleLeftSidebar("") }
        function openLauncher(): void { LauncherService.toggle() }
        function toggleQuickSettings(): void { ConfigProvider.toggleQuickSettings("") }
        function toggleCalendar(): void { ConfigProvider.toggleCalendar("") }
        function toggleShutdown(): void { ConfigProvider.toggleShutdown("") }
        function toggleSettings(): void { ConfigProvider.toggleSettings("") }
        function toggleShortcuts(): void { ConfigProvider.toggleShortcuts("") }
        function toggleWallpaper(): void { ConfigProvider.toggleWallpaper("") }
        function closeAll(): void { ConfigProvider.closeAll() }
    }
}
