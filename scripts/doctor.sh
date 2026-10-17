#!/usr/bin/env bash
set -u

check() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '[ OK ] %-20s %s\n' "$1" "$(command -v "$1")"
  else
    printf '[MISS] %s\n' "$1"
  fi
}

for cmd in nix qs quickshell matugen hyprland hyprctl kitty fish nemo jq; do
  check "$cmd"
done

printf '\nSession files:\n'
for f in /usr/share/wayland-sessions/hyprland.desktop \
         "$HOME/.local/share/wayland-sessions/hyprland.desktop"; do
  [[ -e "$f" ]] && ls -l "$f" || true
done

printf '\nQuickshell config:\n'
ls -ld "$HOME/.config/quickshell/material-hyprland" 2>/dev/null || true
printf '\nHyprland config fragment:\n'
ls -l "$HOME/.config/hypr/material-hyprland.conf" 2>/dev/null || true
