QuickShell Material 3 System Architecture & Specification

An extensible, Material 3 styled desktop environment shell for Hyprland built with QuickShell (QML) and Python backend services.

1. Directory & File Structure

Below is the project structure for the QuickShell repository (qt/ directory):

qt/
├── README.md
├── SPECIFICATION.md
├── shell.qml                        # Main entry point for QuickShell
├── qmldir                          # Module definitions & QML paths
│
├── theme/                          # Material 3 Design System
│   ├── M3Theme.qml                 # Color palette, dark/light state, dynamic seed logic
│   ├── M3Tokens.qml                # Spacing, radii, elevations, transition animations
│   └── Typography.qml              # M3 Typescale (Display, Headline, Body, Label)
│
├── core/                           # System Interfaces & Services
│   ├── HyprlandIPC.qml             # Workspace & window focus listeners
│   ├── SystemServices.qml          # Audio, Network, Bluetooth, Battery bindings
│   └── ConfigProvider.qml          # Dynamic shell settings state & persistent storage
│
├── windows/                        # Window Shell Layers
│   ├── TopBar.qml                  # 1. Dynamic Bar (Top/Bottom/Left/Right, Float/Hug)
│   ├── QuickSettingsPanel.qml      # 2. Controls, Audio, Notifications, Calendar
│   ├── ShortcutWindow.qml          # 3. Keybindings Search & Display
│   ├── SettingsWindow.qml          # 4. M3 Theme & Shell Configurator
│   ├── DesktopClock.qml            # 5. Transparent Ambient Desktop Clock
│   └── AuxiliarySidebar.qml        # 6. Future Side Panel (Widgets, Media, Ollama AI)
│
├── components/                     # Reusable Material 3 Widgets
│   ├── M3Button.qml
│   ├── M3IconButton.qml
│   ├── M3Slider.qml
│   ├── M3Switch.qml
│   ├── M3Card.qml
│   └── M3TextField.qml
│
├── widgets/                        # Modular Panel Widgets
│   ├── WorkspaceBar.qml            # Active workspace indicator
│   ├── ServiceTray.qml             # Quick tray icons
│   ├── CalendarWidget.qml          # M3 Calendar grid
│   ├── CpuRamWidget.qml            # Hardware monitoring visualizer
│   ├── MediaPlayerWidget.qml       # MPRIS audio controller
│   └── AiChatWidget.qml            # Ollama & LLM Chat Interface
│
└── scripts/                        # Python Backend Services & IPC
    ├── system_monitor.py           # Stream CPU/RAM metrics over JSON/IPC
    ├── ollama_client.py            # Local Ollama / Open-AI API bridge
    ├── media_service.py            # MPRIS status parser & album art handler
    └── config_manager.py           # Shell JSON config persistence script


2. System Architecture Diagram

graph TD
    %% Python Backend Layer
    subgraph PythonBackend ["Python Backend Services (scripts/)"]
        SysMonPy["system_monitor.py<br/>(psutil CPU/RAM telemetry)"]
        OllamaPy["ollama_client.py<br/>(Ollama / LLM API streamer)"]
        MediaPy["media_service.py<br/>(MPRIS metadata & controls)"]
    end

    %% QuickShell Engine & Core
    subgraph CoreEngine ["QuickShell Core & State Layer"]
        M3Theme["M3Theme.qml<br/>(Dynamic Material 3 Colors & Tokens)"]
        HyprIPC["HyprlandIPC.qml<br/>(Quickshell.Hyprland bindings)"]
        SysServices["SystemServices.qml<br/>(Audio, Network, Power)"]
        ConfigProv["ConfigProvider.qml<br/>(Bar Position, Shell Tweaks)"]
    end

    %% UI Windows Layer
    subgraph UIWindows ["Shell UI Layers (windows/)"]
        TopBar["<b>1. TopBar.qml</b><br/>• Position: Top/Bottom/Left/Right<br/>• Mode: Hug / Float<br/>• Workspaces, Service Indicators, Time<br/>• Custom File Manager Trigger"]
        
        QuickSettings["<b>2. QuickSettingsPanel.qml</b><br/>• Toggles (Wifi, BT, DND)<br/>• Audio & Brightness Sliders<br/>• Integrated Calendar & Notifications"]
        
        ShortcutWin["<b>3. ShortcutWindow.qml</b><br/>• Categorized Hyprland Keybindings<br/>• Search & Filter Bar"]
        
        SettingsWin["<b>4. SettingsWindow.qml</b><br/>• M3 Dynamic Seed Color Picker<br/>• Bar Position & Style Controls<br/>• Shell Behavior Tweaks"]
        
        BgClock["<b>5. DesktopClock.qml</b><br/>• Layer: Background / Bottom<br/>• Glassmorphic / Transparent<br/>• Click-through Passthrough"]
        
        AuxSidebar["<b>6. AuxiliarySidebar.qml</b><br/>• Hardware Telemetry (CPU/RAM)<br/>• MPRIS Media Player Controls<br/>• Local Ollama AI Chat Drawer"]
    end

    %% Interconnections
    SysMonPy -->|JSON / Socket| AuxSidebar
    OllamaPy <-->|Async Stream| AuxSidebar
    MediaPy <-->|State & Actions| AuxSidebar
    
    HyprIPC <-->|Workspaces & Focus| TopBar
    HyprIPC <-->|Binds List| ShortcutWin
    
    M3Theme --> UIWindows
    ConfigProv --> UIWindows
    SysServices <--> TopBar
    SysServices <--> QuickSettings
    
    TopBar -->|Toggle Popup| QuickSettings
    TopBar -->|Launch Executable| FM["Custom File Manager"]
    SettingsWin -->|Update Config| ConfigProv


3. Detailed Component Specifications

1. TopBar (windows/TopBar.qml)

Window Type: PanelWindow (Layer: Top / Overlay).

Dynamic Anchoring: Supports live position switching (Top, Bottom, Left, Right).

Sizing Modes:

Hug: Spans edge-to-edge or auto-resizes to content fit.

Float: Floating rounded pill with inner paddings and outer margins (margin: 8px, radius: M3Tokens.cornerRadiusFull).

Modules Included:

Active Workspaces indicator connected via HyprlandIPC.qml.

Quick Service Tray (Wi-Fi, Bluetooth, Audio, Battery).

Digital Clock module.

File Explorer action button launching custom file manager via hyprctl dispatch exec.

2. Quick Settings Panel (windows/QuickSettingsPanel.qml)

Window Type: PopupWindow (anchored relative to TopBar tray).

Styling: Material 3 Surface Container High card with backdrop blur.

Modules Included:

Quick Toggles (Wi-Fi, Bluetooth, Night Light, DND).

Interactive Sliders (PipeWire Audio & Brightness).

System Notification Center (history, dismiss, action execution).

Material 3 Calendar Widget.

3. Shortcuts Window (windows/ShortcutWindow.qml)

Window Type: FloatingWindow (Layer: Overlay).

Features:

Reads Hyprland keybindings using hyprctl binds -j.

Categorized grid display (Navigation, Window Management, Workspaces, Launchers).

Interactive search bar using M3TextField.qml.

4. Shell Settings Window (windows/SettingsWindow.qml)

Window Type: AppWindow / Standard Window.

Features:

Bar Layout Tweaks: Position (Top/Bottom/Left/Right) and Mode (Float/Hug).

M3 Dynamic Color Engine: Primary seed color selection, dark/light theme switch, accent tone adjusters.

Config changes automatically saved and broadcast via ConfigProvider.qml.

5. Ambient Desktop Clock (windows/DesktopClock.qml)

Window Type: PanelWindow (Layer: Background).

Features:

Semi-transparent glassmorphic typography.

Input mask disabled / click-through passthrough enabled so desktop interaction remains unimpeded.

6. Auxiliary Sidebar (windows/AuxiliarySidebar.qml)

Window Type: PanelWindow (Anchored to Screen Edge).

Modules Included:

CPU & RAM Monitor Widget: Live usage charts and temperature readings streamed via scripts/system_monitor.py.

Media Player Widget: Album art cover, progress bar, play/pause, skip controls powered by scripts/media_service.py.

Local Ollama AI Chat Widget: Natural language chat powered asynchronously by scripts/ollama_client.py using local LLM models (e.g., Llama 3, Qwen 2.5, Mistral).

4. Python Integration Specification

All Python scripts communicate with QuickShell via standard IO streams, Unix Domain Sockets, or HTTP endpoints:

system_monitor.py: Uses psutil to emit periodic JSON packets:

{"cpu_usage": 14.2, "ram_usage": 42.8, "ram_used_gb": 6.8, "ram_total_gb": 16.0}


ollama_client.py: Handles asynchronous HTTP POST requests to http://localhost:11434/api/generate and streams response tokens directly into AiChatWidget.qml.

media_service.py: Uses dbus-python or mpris modules to track active players, track titles, artists, and playback state.