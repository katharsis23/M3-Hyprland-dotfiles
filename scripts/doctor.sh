for cmd in nix qs quickshell matugen starship hyprland hyprctl kitty fish nemo jq; do
  check "$cmd"
done

printf '\nSession files:\n'
for f in /usr/share/wayland-sessions/hyprland.desktop \
         "$HOME/.local/share/wayland-sessions/hyprland.desktop"; do
  [[ -e "$f" ]] && ls -l "$f" || true
done

printf '\nQuickshell config:\n'
ls -ld "$HOME/.config/quickshell/material-hyprland" 2>/dev/null || true
printf '  shell entry    : %s\n' \
  "$([[ -f "$HOME/.config/quickshell/material-hyprland/qt/shell.qml" ]] && echo OK || echo MISSING)"

printf '\nAutostart (Hyprland exec-once):\n'
if grep -q 'qs -c material-hyprland/qt' "$HOME/.config/hypr/hyprland/execs.conf" 2>/dev/null; then
  echo "  quickshell autostart: OK"
else
  echo "  quickshell autostart: MISSING (re-run scripts/install.sh)"
fi
# The Nix package runs ``quickshell-wrapped-<ver>`` (``qs`` is a shim), so an
# exact ``pgrep -x quickshell`` never matches; use ``-f`` on the command line.
if pgrep -f '[q]uickshell' >/dev/null 2>&1; then
  echo "  running now        : yes"
else
  echo "  running now        : no"
fi
printf '  runtime log    : %s (%s)\n' \
  "$HOME/.cache/material-hyprland/quickshell.log" \
  "$([[ -f "$HOME/.cache/material-hyprland/quickshell.log" ]] && echo present || echo absent)"

printf '\nHyprland config fragment:\n'
ls -l "$HOME/.config/hypr/material-hyprland.conf" 2>/dev/null || true

printf '\nTerminal theme stack:\n'
printf '  matugen config : %s\n' \
  "$([[ -f "$HOME/.config/matugen/config.toml" ]] && echo OK || echo MISSING)"
printf '  templates      : %s\n' \
  "$([[ -d "$HOME/.config/matugen/templates" ]] && echo OK || echo MISSING)"
printf '  kitty config   : %s\n' \
  "$([[ -f "$HOME/.config/kitty/kitty.conf" ]] && echo OK || echo MISSING)"
printf '  fish config    : %s\n' \
  "$([[ -f "$HOME/.config/fish/config.fish" ]] && echo OK || echo MISSING)"
printf '  starship config: %s\n' \
  "$([[ -f "$HOME/.config/starship.toml" ]] && echo OK || echo MISSING)"
printf '  apply-theme.sh : %s\n' \
  "$([[ -x "$HOME/.config/hypr/scripts/apply-theme.sh" ]] && echo OK || echo MISSING)"

printf '\nGenerated theme files (~/.local/state/theme/generated):\n'
gen="${XDG_STATE_HOME:-$HOME/.local/state}/theme/generated"
if [[ -d "$gen" ]]; then
  ls -1 "$gen" 2>/dev/null | sed 's/^/  - /'
else
  echo "  (none yet — run scripts/apply-theme.sh after setting a wallpaper)"
fi

printf '\nNerd Font availability:\n'
if command -v fc-list >/dev/null 2>&1; then
  if fc-list | grep -qi 'JetBrainsMono Nerd Font'; then
    echo "  JetBrainsMono Nerd Font: OK"
  else
    echo "  JetBrainsMono Nerd Font: MISSING (run scripts/install.sh)"
  fi
else
  echo "  fc-list not found"
fi

