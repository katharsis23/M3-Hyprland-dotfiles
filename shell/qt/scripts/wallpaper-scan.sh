#!/usr/bin/env bash
# Wallpaper helper for the in-shell picker (windows/WallpaperPicker.qml).
#
#   wallpaper-scan.sh list         # one absolute image path per line
#   wallpaper-scan.sh current      # active wallpaper path (may be empty)
#   wallpaper-scan.sh set <path>   # apply a wallpaper + regenerate the theme
#   wallpaper-scan.sh blur [on|off|toggle]  # query/set wallpaper blur
#
# The heavy lifting lives in hypr/scripts/wallpaper_manager.py (installed to
# ~/.config/hypr/scripts/). This wrapper just locates it and, if it is missing,
# falls back to a pure-bash listing so the picker still shows something.
set -o pipefail

CMD="${1:-list}"
shift || true

# Locate wallpaper_manager.py: installed location first, then the repo copy
# relative to the linked shell (~/.config/quickshell/material-hyprland).
find_manager() {
  local p
  for p in \
    "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/wallpaper_manager.py" \
    "$HOME/.config/hypr/scripts/wallpaper_manager.py" \
    "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")/../../../hypr/scripts/wallpaper_manager.py"; do
    [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

MANAGER="$(find_manager || true)"

# Directories searched when the manager is unavailable (kept in sync with it).
wallpaper_dirs() {
  [[ -n "${WALLPAPER_DIR:-}" ]] && printf '%s\n' "$WALLPAPER_DIR"
  printf '%s\n' \
    "$HOME/.config/hypr/wallpapers" \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Pictures"
}

fallback_list() {
  local dir
  while IFS= read -r dir; do
    [[ -d "$dir" ]] || continue
    find "$dir" -maxdepth 1 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
         -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) 2>/dev/null
  done < <(wallpaper_dirs) | sort -u
}

case "$CMD" in
  list)
    if [[ -n "$MANAGER" ]] && command -v python3 >/dev/null 2>&1; then
      python3 "$MANAGER" list 2>/dev/null || fallback_list
    else
      fallback_list
    fi
    ;;
  current)
    if [[ -n "$MANAGER" ]] && command -v python3 >/dev/null 2>&1; then
      python3 "$MANAGER" current 2>/dev/null || true
    else
      last="${XDG_CACHE_HOME:-$HOME/.cache}/material-hyprland/last-wallpaper"
      [[ -f "$last" ]] && head -n1 "$last"
    fi
    ;;
  set)
    target="${1:-}"
    [[ -n "$target" ]] || { echo "wallpaper-scan: set needs a path" >&2; exit 2; }
    if [[ -n "$MANAGER" ]] && command -v python3 >/dev/null 2>&1; then
      python3 "$MANAGER" "$target"
    elif command -v awww >/dev/null 2>&1; then
      awww img "$target" --transition-type grow --transition-duration 1.2
    elif command -v swww >/dev/null 2>&1; then
      swww img "$target" --transition-type grow --transition-duration 1.2
    else
      echo "wallpaper-scan: no wallpaper manager available" >&2
      exit 1
    fi
    ;;
  blur)
    if [[ -n "$MANAGER" ]] && command -v python3 >/dev/null 2>&1; then
      python3 "$MANAGER" blur "$@"
    else
      # Fallback: mirror the manager's state file so the toggle still works
      # for the UI even without the python helper.
      state="${XDG_CACHE_HOME:-$HOME/.cache}/material-hyprland/wallpaper-blur"
      mkdir -p "$(dirname "$state")"
      case "${1:-}" in
        on)     printf '1\n' > "$state" ;;
        off)    printf '0\n' > "$state" ;;
        toggle) if [[ "$(cat "$state" 2>/dev/null)" == "1" ]]; then printf '0\n' > "$state"; else printf '1\n' > "$state"; fi ;;
        "")     ;;
        *)      echo "wallpaper-scan: blur expects on|off|toggle" >&2; exit 2 ;;
      esac
      [[ "$(cat "$state" 2>/dev/null)" == "1" ]] && echo on || echo off
    fi
    ;;
  *)
    echo "wallpaper-scan: unknown command '$CMD'" >&2
    exit 2
    ;;
esac
