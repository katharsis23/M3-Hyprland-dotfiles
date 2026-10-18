set fish_greeting

      function starship_transient_prompt_func
          starship module character
      end
      if test "$TERM" != "linux"
          starship init fish | source
          enable_transience
      end

# Colors (matugen-driven Material 3 theme)
set theme_generated $HOME/.local/state/theme/generated

# Fish syntax colours generated from the active wallpaper.
set theme_fish_colors $theme_generated/fish-colors.fish
if test -f $theme_fish_colors
    source $theme_fish_colors
      end

# Use the matugen-generated Starship palette once it exists; otherwise fall
# back to the static bundled config (~/.config/starship.toml).
if test -f $theme_generated/starship.toml
    set -gx STARSHIP_CONFIG $theme_generated/starship.toml
      end

alias clear "printf '\033[2J\033[3J\033[1;1H'"
alias celar "printf '\033[2J\033[3J\033[1;1H'"
alias claer "printf '\033[2J\033[3J\033[1;1H'"
alias q 'qs -c ~/.config/quickshell/material-hyprland/qt'

# Re-apply the current wallpaper's theme without leaving the shell.
function theme
    set -l apply ~/.config/hypr/scripts/apply-theme.sh
    if not test -x $apply
        echo "theme: $apply not found (run scripts/install.sh)" >&2
        return 1
    end
    switch "$argv[1]"
        case '' regenerate restore
            if set -q THEME_MODE
                $apply --mode=$THEME_MODE
            else
                $apply
            end
        case '*'
            echo "usage: theme [regenerate|restore]" >&2
            return 1
    end
    test -f $theme_fish_colors; and source $theme_fish_colors
    test -f $theme_generated/starship.toml; and set -gx STARSHIP_CONFIG $theme_generated/starship.toml
end

if test "$TERM" != "linux"
    alias ls 'eza --icons=auto'
end

if test "$TERM" = "xterm-kitty"
    alias ssh 'kitten ssh'
end

# Create /etc/deepseek.key and set it
# if test -f /etc/deepseek.key
#     set -gx DEEPSEEK_API_KEY (cat /etc/deepseek.key)
# end

