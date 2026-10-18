#!/usr/bin/env bash
# ~/.config/hypr/scripts/toggle_qs.sh
# Kill the running Quickshell instance, or relaunch the Material 3 shell.
# The config lives in ~/.config/quickshell/material-hyprland/qt (see install.sh).

QS_CONFIG="material-hyprland/qt"

if pgrep -x quickshell >/dev/null 2>&1; then
    killall quickshell
else
    mkdir -p "$HOME/.cache/material-hyprland"
    setsid qs -c "$QS_CONFIG" >> "$HOME/.cache/material-hyprland/quickshell.log" 2>&1 &
fi