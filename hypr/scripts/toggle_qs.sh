#!/usr/bin/env bash
# ~/.config/hypr/scripts/toggle_qs.sh
# Kill the running Quickshell instance, or relaunch the Material 3 shell.
# The config lives in ~/.config/quickshell/material-hyprland/qt (see install.sh).

QS_CONFIG="material-hyprland/qt"

# The Nix package's real process is ``quickshell-wrapped-<ver>`` and ``qs`` is a
# shim, so match on the command line (``pgrep -f``) rather than the exact name.
# Using ``-x quickshell`` / ``killall quickshell`` here never matched, which made
# this script spawn a duplicate shell instead of toggling the existing one.
if pgrep -f '[q]uickshell' >/dev/null 2>&1; then
    pkill -f '[q]uickshell'
else
    mkdir -p "$HOME/.cache/material-hyprland"
    setsid qs -c "$QS_CONFIG" >> "$HOME/.cache/material-hyprland/quickshell.log" 2>&1 &
fi