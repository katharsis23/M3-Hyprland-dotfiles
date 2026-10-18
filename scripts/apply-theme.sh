#!/usr/bin/env bash
# apply-theme.sh — generate the Material 3 palette with matugen.
#
# Regenerates kitty / fish / starship / GTK / Quickshell colour files from a
# wallpaper image, then nudges running terminals and GTK apps to reload.
#
# Usage:
#   apply-theme.sh [IMAGE] [options]
#
#   IMAGE            Wallpaper to sample. Defaults to the last wallpaper set by
#                    hypr/scripts/wallpaper_manager.py, or the first image found
#                    in the usual wallpaper directories.
#
# Options:
#   --mode dark|light   Colour scheme mode (default: dark).
#   --type TYPE         matugen scheme type (default: scheme-tonal-spot).
#   --contrast N        matugen contrast, -1..1 (default: 0).
#   -h, --help          Show help.
#
# Requires: matugen (see dependencies.json). Uses the config at
# ~/.config/matugen/config.toml, installed by scripts/install.sh.
set -Eeuo pipefail

# Default mode comes from the persisted shell choice (see below); the literal
# fallback keeps the script usable before the shell ever wrote it.
MODE=""
SCHEME_TYPE="scheme-tonal-spot"
CONTRAST="0"
IMAGE=""

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (($#)); do
  case "$1" in
    --mode)     MODE="${2:?--mode needs a value}"; shift 2 ;;
    --mode=*)   MODE="${1#*=}"; shift ;;
    --type)     SCHEME_TYPE="${2:?--type needs a value}"; shift 2 ;;
    --type=*)   SCHEME_TYPE="${1#*=}"; shift ;;
    --contrast) CONTRAST="${2:?--contrast needs a value}"; shift 2 ;;
    --contrast=*) CONTRAST="${1#*=}"; shift ;;
    -h|--help)  usage; exit 0 ;;
    --)         shift; break ;;
    -*)         echo "apply-theme: unknown option $1" >&2; exit 2 ;;
    *)          IMAGE="$1"; shift ;;
  esac
done

# Resolve the state dir early so we can read a persisted mode when none given.
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/theme"

if [[ -z "$MODE" ]]; then
  if [[ -f "$STATE_ROOT/mode" ]]; then
    MODE="$(head -n1 "$STATE_ROOT/mode" | tr -d '[:space:]')"
  fi
  [[ -n "$MODE" ]] || MODE="dark"
fi

case "$MODE" in dark|light) ;; *) echo "apply-theme: --mode must be dark or light" >&2; exit 2 ;; esac

log()  { printf '\033[1;34m[theme]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[theme]\033[0m %s\n' "$*" >&2; }

command -v matugen >/dev/null 2>&1 || { echo "apply-theme: matugen not found (run scripts/install.sh)" >&2; exit 1; }
command -v python3  >/dev/null 2>&1 || { echo "apply-theme: python3 not found" >&2; exit 1; }

STATE_DIR="$STATE_ROOT/generated"
mkdir -p "$STATE_DIR"

# Persist the chosen mode so wallpaper changes (wallpaper_manager.py) and later
# runs keep the light/dark choice made in the shell settings.
printf '%s\n' "$MODE" > "$STATE_ROOT/mode"

# --- Resolve a wallpaper if none was given ---------------------------------
pick_wallpaper() {
  local last="${XDG_CACHE_HOME:-$HOME/.cache}/material-hyprland/last-wallpaper"
  if [[ -f "$last" ]]; then echo "$(head -n1 "$last")"; return; fi
  local dir
  for dir in "${WALLPAPER_DIR:-}" \
             "$HOME/.config/hypr/wallpapers" \
             "$HOME/Pictures/Wallpapers" \
             "$HOME/Pictures"; do
    [[ -n "$dir" && -d "$dir" ]] || continue
    local img
    img="$(find "$dir" -maxdepth 1 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
               -o -iname '*.webp' -o -iname '*.bmp' \) 2>/dev/null | sort | head -n1)"
    [[ -n "$img" ]] && { echo "$img"; return; }
  done
}

if [[ -z "$IMAGE" ]]; then
  IMAGE="$(pick_wallpaper || true)"
fi

MATUGEN_ARGS=(--mode "$MODE" --type "$SCHEME_TYPE" --contrast "$CONTRAST")
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml"
[[ -f "$CONFIG" ]] && MATUGEN_ARGS+=(--config "$CONFIG")

if [[ -n "$IMAGE" ]]; then
  [[ -f "$IMAGE" ]] || { echo "apply-theme: image not found: $IMAGE" >&2; exit 1; }
  log "Generating theme from: $IMAGE (mode=$MODE)"
  matugen image "$IMAGE" "${MATUGEN_ARGS[@]}"
else
  # No wallpaper available: seed a sensible Material baseline so the terminal
  # files still exist. Re-run once a wallpaper is set.
  warn "No wallpaper found; seeding palette from the Material baseline colour."
  matugen color hex '#6750A4' "${MATUGEN_ARGS[@]}"
fi

# --- Reload running consumers ----------------------------------------------
# kitty: tell every live instance to re-read its config.
if command -v kitty >/dev/null 2>&1; then
  if kitty @ ls >/dev/null 2>&1; then
    kitty @ load-config >/dev/null 2>&1 && log "Reloaded kitty config." || true
  fi
fi

# GTK apps (file manager, settings dialogs, …): flip the colour-scheme preference
# so libadwaita/GTK pick the matching variant, and nudge live apps to re-read CSS.
if command -v gsettings >/dev/null 2>&1; then
  if [[ "$MODE" == "dark" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
  fi
  # Hint GTK3 apps to repaint with the regenerated @define-color palette.
  gsettings set org.gnome.desktop.interface gtk-theme "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo '')" 2>/dev/null || true
  log "Updated GTK color-scheme (mode=$MODE)."
fi

# fish: only affects new shells; current shells can run `theme` to re-source.
log "Generated theme files in $STATE_DIR:"
ls -1 "$STATE_DIR" 2>/dev/null | sed 's/^/  - /'
log "Also wrote GTK colours: ~/.config/gtk-3.0/gtk.css and ~/.config/gtk-4.0/gtk.css"
log "Open a new terminal (or run \`theme\` in fish) to pick up the colours."
