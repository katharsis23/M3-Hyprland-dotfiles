#!/usr/bin/env bash
# ~/.config/hypr/scripts/toggle_qs.sh

if pgrep -x "quickshell" > /dev/null; then
    killall quickshell
else
    quickshell &
fi