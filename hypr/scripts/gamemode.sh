#!/usr/bin/env bash
# ~/.config/hypr/scripts/gamemode.sh

set -e pipefail

HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')

if [ "$HYPRGAMEMODE" = 1 ] ; then
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword decoration:rounding 0"
    notify-send "Hyprland" "Game Mode Enabled (Effects Disabled)"
    exit
fi

hyprctl reload
notify-send "Hyprland" "Game Mode Disabled (Effects Restored)"