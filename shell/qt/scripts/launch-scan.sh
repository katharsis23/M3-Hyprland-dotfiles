#!/usr/bin/env bash
# Enumerate applications from XDG .desktop files.
# Output: one record per line, fields separated by '|': NAME|GENERIC|ICON|EXEC
set -o pipefail
DIRS="$HOME/.local/share/applications /usr/local/share/applications /usr/share/applications"
if [ -n "${XDG_DATA_DIRS:-}" ]; then
  IFS=":"; for d in $XDG_DATA_DIRS; do DIRS="$DIRS $d/applications"; done; unset IFS
fi
find $DIRS -maxdepth 1 -name "*.desktop" 2>/dev/null | sort -u | while IFS= read -r f; do
  body=$(sed -n '/^\[Desktop Entry\]/,/^\[/p' "$f")
  printf '%s\n' "$body" | grep -q '^Type=Application' || continue
  printf '%s\n' "$body" | grep -qE '^(Hidden|NoDisplay)=true' && continue
  name=$(printf '%s\n' "$body" | sed -n 's/^Name=//p' | head -1)
  generic=$(printf '%s\n' "$body" | sed -n 's/^GenericName=//p' | head -1)
  icon=$(printf '%s\n' "$body" | sed -n 's/^Icon=//p' | head -1)
  exec=$(printf '%s\n' "$body" | sed -n 's/^Exec=//p' | head -1 | sed 's/ *%[fFuUdDnNickvm]//g')
  [ -z "$name" ] && continue
  printf '%s|%s|%s|%s\n' "$name" "$generic" "$icon" "$exec"
done
