#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$ROOT_DIR/dependencies.json"

DRY_RUN=0
VIA_NIX=0
SKIP_PACKAGES=0
SKIP_CONFIG=0
ASSUME_YES=0
SOURCE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/material-hyprland/src"

# TODO: !! Add git clone AI-girlfriend from https://github.com/katharsis23/AI_girlfriend_chat.git


usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]
  --via-nix          Install ALL packages through Nix (skips APT and source builds)
  --dry-run          Print planned actions without changing the system
  --skip-packages    Skip dependency installation; apply config only
  --skip-config      Install packages only; do not apply config
  -y, --yes          Do not ask for confirmation
  -h, --help         Show help

Default backend: APT first. If a package is not available in your APT
repositories it is built from source as declared in dependencies.json.
Some dependencies (Nerd Fonts, starship) are fetched as upstream release
artifacts into ~/.local because they are not packaged for APT.

Config step installs the Hyprland modules plus the terminal theme stack:
matugen (config + templates), kitty, fish and starship, then generates an
initial Material 3 palette from the current wallpaper. Re-run the palette at
any time with scripts/apply-theme.sh [image] (or `theme` inside fish).

Besides the desktop stack, this installer provisions the AI companion
backend used by the AI sidebar: it installs Poetry and runs `poetry install`
for the AI_girlfriend_chat checkout (set AI_GIRLFRIEND_HOME to override its
location). The resolved path is recorded in
~/.config/material-hyprland/ai-backend.env and sourced from your shell profile.

This installer does not edit SDDM or remove Cinnamon. Keep Cinnamon as a
recovery session.
EOF
}

while (($#)); do
  case "$1" in
    --via-nix) VIA_NIX=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-config) SKIP_CONFIG=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

log()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
  (( ASSUME_YES )) && return 0
  [[ -t 0 ]] || return 1
  local answer
  read -r -p "$1 [y/N] " answer
  [[ "${answer,,}" == y || "${answer,,}" == yes ]]
}

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  (( DRY_RUN )) || "$@"
}

backup_file() {
  local file="$1" stamp
  [[ -e "$file" ]] || return 0
  stamp="$(date +%Y%m%d-%H%M%S)"
  run cp -a -- "$file" "$file.material-hyprland-backup-$stamp"
}

have() { command -v "$1" >/dev/null 2>&1; }

command -v python3 >/dev/null 2>&1 || die "python3 is required."
[[ -f "$MANIFEST" ]] || die "Missing manifest: $MANIFEST"
python3 -m json.tool "$MANIFEST" >/dev/null || die "Invalid JSON manifest."

# --- Manifest parsing ------------------------------------------------------
# manifest_rows prints one tab-separated row per package. The final field is a
# base64-encoded JSON blob (or "-") so the shell never parses nested objects.
manifest_rows() {
  python3 - "$MANIFEST" <<'PY'
import base64, json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
for p in data["packages"]:
    src = p.get("source")
    blob = base64.b64encode(
        json.dumps(src).encode("utf-8")).decode("ascii") if src else "-"
    fields = [
        p["name"],
        "required" if p.get("required") else "optional",
        p.get("apt_name") or "-",
        p.get("nix_attr") or "-",
        blob,
    ]
    print("\t".join(fields))
PY
}

source_build_deps() {
  python3 - "$1" <<'PY'
import base64, json, sys
blob = sys.argv[1]
if blob == "-":
    sys.exit(0)
src = json.loads(base64.b64decode(blob).decode("utf-8"))
print(" ".join(src.get("apt_build_deps", [])))
PY
}

source_field() {
  python3 - "$1" "$2" <<'PY'
import base64, json, sys
blob, key = sys.argv[1], sys.argv[2]
if blob == "-":
    sys.exit(0)
src = json.loads(base64.b64decode(blob).decode("utf-8"))
val = src.get(key, "")
print(" ".join(str(v) for v in val) if isinstance(val, list) else val)
PY
}

# --- Install backends ------------------------------------------------------
APT_CACHE_VALID=0

apt_refresh() {
  (( APT_CACHE_VALID )) && return 0
  if (( DRY_RUN )); then
    log "Would run apt-get update"
  elif (( ASSUME_YES )); then
    sudo apt-get update
  fi
  APT_CACHE_VALID=1
}

apt_available() { apt-cache show "$1" >/dev/null 2>&1; }

apt_install() {
  local pkg="$1"
  have apt-get || { warn "APT is unavailable."; return 127; }
  if (( DRY_RUN )); then
    log "Would install APT package: $pkg"
    return 0
  fi
  sudo apt-get install -y "$pkg"
}

nix_install() {
  local attr="$1"
  have nix || { warn "Nix is unavailable."; return 127; }
  if (( DRY_RUN )); then
    log "Would install Nix package: nixpkgs#$attr"
    return 0
  fi
  nix --extra-experimental-features "nix-command flakes" \
      profile install "nixpkgs#$attr"
}

# Clone (or update) a source repo into the cache and echo the directory.
fetch_source() {
  local name="$1" repo="$2" ref="$3" dest="$SOURCE_CACHE/$1"
  have git || { warn "git is required to build $name from source."; return 1; }
  if (( DRY_RUN )); then
    # Log to stderr so only the resolved path goes to stdout (captured by caller).
    log "Would clone $repo${ref:+ ($ref)} into $dest" >&2
    echo "$dest"
    return 0
  fi
  mkdir -p "$SOURCE_CACHE"
  if [[ -d "$dest/.git" ]]; then
    log "Updating existing source checkout: $dest"
    git -C "$dest" fetch --tags --depth 1 origin || true
  else
    rm -rf "$dest"
    local clone_args=(clone --depth 1)
    [[ -n "$ref" ]] && clone_args+=(--branch "$ref")
    git clone "${clone_args[@]}" "$repo" "$dest" >&2
  fi
  echo "$dest"
}

build_cmake() {
  local name="$1" blob="$2" repo ref prefix dest deps
  repo="$(source_field "$blob" repo)"
  ref="$(source_field "$blob" ref)"
  prefix="$(source_field "$blob" install_prefix)"
  prefix="${prefix:-/usr/local}"
  deps="$(source_build_deps "$blob")"

  if [[ -n "$deps" ]]; then
    log "Installing build dependencies for $name: $deps"
    # shellcheck disable=SC2086
    run sudo apt-get install -y $deps
  fi

  dest="$(fetch_source "$name" "$repo" "$ref")" || return 1
  log "Configuring $name (cmake)"
  run cmake -S "$dest" -B "$dest/build" -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$prefix"
  log "Building $name"
  run cmake --build "$dest/build"
  log "Installing $name to $prefix"
  run sudo cmake --install "$dest/build"
}

build_cargo() {
  local name="$1" blob="$2" repo dest deps install_args
  repo="$(source_field "$blob" repo)"
  install_args="$(source_field "$blob" install_args)"
  deps="$(source_build_deps "$blob")"

  if [[ -n "$deps" ]]; then
    log "Installing build dependencies for $name: $deps"
    # shellcheck disable=SC2086
    run sudo apt-get install -y $deps
  fi

  dest="$(fetch_source "$name" "$repo" "")" || return 1
  log "Installing $name (cargo)"
  if (( DRY_RUN )); then
    log "Would run: cargo install --path $dest --force $install_args"
    return 0
  fi
  have cargo || { warn "cargo is required to build $name from source."; return 1; }
  # shellcheck disable=SC2086
  sudo cargo install --path "$dest" --force $install_args
}

build_go() {
  local name="$1" blob="$2" repo bin dest deps
  repo="$(source_field "$blob" repo)"
  bin="$(source_field "$blob" bin)"
  deps="$(source_build_deps "$blob")"

  if [[ -n "$deps" ]]; then
    log "Installing build dependencies for $name: $deps"
    # shellcheck disable=SC2086
    run sudo apt-get install -y $deps
  fi

  have go || { warn "go is required to build $name from source."; return 1; }
  dest="$(fetch_source "$name" "$repo" "")" || return 1
  log "Building $name (go)"
  if (( DRY_RUN )); then
    log "Would run: (cd $dest && go build -o /usr/local/bin/$bin .)"
    return 0
  fi
  ( cd "$dest" && sudo go build -o "/usr/local/bin/$bin" . )
}

build_from_source() {
  local name="$1" blob="$2" kind
  kind="$(source_field "$blob" kind)"
  case "$kind" in
    cmake) build_cmake "$name" "$blob" ;;
    cargo) build_cargo "$name" "$blob" ;;
    go)    build_go "$name" "$blob" ;;
    *)     warn "Unknown source build kind '$kind' for $name."; return 1 ;;
  esac
}

# --- AI companion backend (AI_girlfriend_chat) ------------------------------
# The Quickshell AI sidebar talks to a local Python backend over JSON/stdio
# (see shell/qt/core/AiBridge.qml and shell/Ai_sidebar_specification.md). The
# backend needs Python 3.11+, Poetry, and its Poetry env installed. The path is
# recorded in the shell so AiBridge can spawn `python -m ...ipc_server`.

# Allow the user to point at an existing checkout; otherwise use the default.
AI_BACKEND_DIR="${AI_GIRLFRIEND_HOME:-$HOME/Projects/AI-girlfriend/AI_girlfriend_chat}"

poetry_bin() {
  # Poetry installs to ~/.local/bin (or XDG_BIN_HOME); fall back to PATH.
  local candidate="${XDG_BIN_HOME:-$HOME/.local/bin}/poetry"
  if [[ -x "$candidate" ]]; then echo "$candidate"; return 0; fi
  have poetry && { command -v poetry; return 0; }
  return 1
}

install_poetry() {
  if poetry_bin >/dev/null 2>&1 && [[ "$(poetry_bin)" != "poetry" || -n "$(command -v poetry 2>/dev/null)" ]]; then
    ok "Poetry already installed: $(poetry_bin || true)"
    return 0
  fi
  if (( DRY_RUN )); then
    log "Would install Poetry via https://install.python-poetry.org"
    return 0
  fi
  have curl || { warn "curl is required to install Poetry."; return 1; }
  have python3 || { warn "python3 is required to install Poetry."; return 1; }
  log "Installing Poetry (official installer)…"
  if curl -sSL https://install.python-poetry.org | python3 - >/dev/null; then
    local pb; pb="$(poetry_bin || true)"
    ok "Installed Poetry: ${pb:-poetry}"
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
    return 0
  fi
  warn "Poetry installer failed; install it manually: curl -sSL https://install.python-poetry.org | python3 -"
  return 1
}

install_ai_backend() {
  local pb
  if [[ ! -d "$AI_BACKEND_DIR" ]]; then
    warn "AI backend checkout not found at: $AI_BACKEND_DIR"
    warn "Set AI_GIRLFRIEND_HOME to your AI_girlfriend_chat checkout and re-run, or clone it there."
    return 1
  fi
  install_poetry || return 1
  pb="$(poetry_bin || true)"
  [[ -n "$pb" ]] || { warn "Poetry binary not found after install."; return 1; }

  if (( DRY_RUN )); then
    log "Would run: (cd $AI_BACKEND_DIR && $pb install)"
    log "Would record AI_GIRLFRIEND_HOME=$AI_BACKEND_DIR in the shell profile."
    return 0
  fi

  # Prefer an in-project .venv so AiBridge can find it at the default
  # location (<backend>/.venv/bin/python) even without env vars. This is
  # scoped to the backend dir via `poetry config --local`.
  ( cd "$AI_BACKEND_DIR" && "$pb" config --local virtualenvs.in-project true ) || \
    warn "Could not set virtualenvs.in-project for the backend (continuing)."

  log "Installing AI backend dependencies in $AI_BACKEND_DIR …"
  # `poetry install` creates the project venv and installs PySide6/pydantic etc.
  if ( cd "$AI_BACKEND_DIR" && "$pb" install --no-interaction ); then
    ok "AI backend dependencies installed."
  else
    warn "poetry install failed; the AI sidebar will not start until this succeeds."
    return 1
  fi

  # Resolve the interpreter Poetry created so we can bake it into the profile.
  local env_path py
  env_path="$( cd "$AI_BACKEND_DIR" && "$pb" env info -p 2>/dev/null || true )"
  py="$env_path/bin/python"
  if [[ -x "$py" ]]; then
    # If Poetry still used a cache venv (in-project not honoured), expose it at
    # the backend's default .venv so AiBridge finds it without any env vars.
    local in_project="$AI_BACKEND_DIR/.venv"
    if [[ "$env_path" != "$in_project" && ! -e "$in_project" ]]; then
      ln -s "$env_path" "$in_project" \
        && ok "Linked $in_project -> $env_path (for AiBridge's default path)"
    fi
    record_ai_env "$AI_BACKEND_DIR" "$py"
  else
    warn "Could not resolve the backend virtualenv interpreter."
    record_ai_env "$AI_BACKEND_DIR" ""
  fi
  return 0
}

# Persist the backend location so AiBridge (a separate process) can find it.
# Written to a small env file sourced from the shell profiles.
record_ai_env() {
  local home_dir="$1" py="$2"
  local env_file="$HOME/.config/material-hyprland/ai-backend.env"
  mkdir -p "$(dirname -- "$env_file")"
  {
    echo "# Generated by install.sh — AI companion backend location."
    echo "export AI_GIRLFRIEND_HOME=\"$home_dir\""
    [[ -n "$py" ]] && echo "export AI_GIRLFRIEND_PYTHON=\"$py\""
  } >"$env_file"
  ok "Recorded AI backend location in $env_file"

  # Source the env file from shell profiles (add Fish as a one-liner too).
  local block='# AI companion backend (material-hyprland)\n[ -f "$HOME/.config/material-hyprland/ai-backend.env" ] && . "$HOME/.config/material-hyprland/ai-backend.env"'
  local prof
  for prof in "$HOME/.bashrc" "$HOME/.profile"; do
    [[ -e "$prof" ]] || continue
    if ! grep -q "ai-backend.env" "$prof"; then
      printf '\n%b\n' "$block" >>"$prof"
      ok "Added AI backend env sourcing to $prof"
    fi
  done
  local fish_dir="$HOME/.config/fish"
  if [[ -d "$fish_dir" ]]; then
    local fish_block='if test -f "$HOME/.config/material-hyprland/ai-backend.env"\n    for line in (cat "$HOME/.config/material-hyprland/ai-backend.env")\n        set -gx (string replace -r "^export " "" $line | string split "=" -m 2)\n    end\nend'
    if ! grep -q "ai-backend.env" "$fish_dir/config.fish" 2>/dev/null; then
      printf '\n%b\n' "$fish_block" >>"$fish_dir/config.fish"
      ok "Added AI backend env sourcing to $fish_dir/config.fish"
    fi
  fi
}



# Resolve one package in default (APT-first) mode.
install_package_default() {
  local name="$1" apt_name="$2" blob="$3"
  if [[ "$apt_name" != "-" ]]; then
    apt_refresh
    if apt_available "$apt_name"; then
      apt_install "$apt_name" && return 0
    else
      log "APT has no package '$apt_name' for $name."
    fi
  fi
  if [[ "$blob" != "-" ]]; then
    log "Building $name from source."
    build_from_source "$name" "$blob" && return 0
  fi
  return 1
}

# --- Special-case package installers ---------------------------------------
# Some dependencies are not packaged in APT and have no source recipe in the
# manifest; they are fetched as upstream release artifacts into ~/.local.

install_nerd_font() {
  local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd Font'; then
    ok "JetBrainsMono Nerd Font already available."
    return 0
  fi
  if (( DRY_RUN )); then
    log "Would download JetBrainsMono Nerd Font into $font_dir and run fc-cache."
    return 0
  fi
  have curl || { warn "curl is required to download Nerd Fonts."; return 1; }
  have unzip || { warn "unzip is required to extract Nerd Fonts."; return 1; }
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  local tmp; tmp="$(mktemp -d)"
  log "Downloading JetBrainsMono Nerd Font…"
  if ! curl -fL --retry 3 -o "$tmp/JetBrainsMono.zip" "$url"; then
    warn "Failed to download Nerd Font archive from $url"
    rm -rf "$tmp"; return 1
  fi
  mkdir -p "$font_dir"
  unzip -oq "$tmp/JetBrainsMono.zip" -d "$font_dir"
  rm -rf "$tmp"
  have fc-cache && fc-cache -f "$font_dir" >/dev/null 2>&1 || true
  ok "Installed Nerd Fonts into $font_dir"
}

install_starship() {
  local bin_dir="$HOME/.local/bin" dest="$HOME/.local/bin/starship"
  if have starship; then
    ok "starship already on PATH: $(command -v starship)"
    return 0
  fi
  if (( DRY_RUN )); then
    log "Would install starship into $dest (upstream install script)."
    return 0
  fi
  have curl || { warn "curl is required to install starship."; return 1; }
  mkdir -p "$bin_dir"
  log "Installing starship into $bin_dir via the upstream installer…"
  if curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$bin_dir" >/dev/null; then
    ok "Installed starship into $bin_dir"
    case ":$PATH:" in *":$bin_dir:"*) ;; *) export PATH="$bin_dir:$PATH" ;; esac
    return 0
  fi
  warn "starship install script failed; install it manually from https://starship.rs"
  return 1
}

# Route a manifest package to a special-case installer when applicable.
# Returns 127 when the package is not special-cased.
install_special_package() {
  case "$1" in
    nerd-fonts) install_nerd_font ;;
    starship)   install_starship ;;
    poetry)     install_poetry ;;
    *)          return 127 ;;
  esac
}

# --- Package installation --------------------------------------------------
install_packages() {
  local -a failed_required=()

  if (( VIA_NIX )); then
    have nix || die "--via-nix requested but nix is not installed."
    log "Backend: Nix (fully self-contained; APT and source are skipped)."
  else
    have apt-get || die "APT is required in the default backend (or pass --via-nix)."
    log "Backend: APT first, source build when a package is not in APT."
  fi

  local name required apt_name nix_attr blob
  while IFS=$'\t' read -r name required apt_name nix_attr blob; do
    [[ -n "$name" ]] || continue
    log "Package $name ($required)"

    local installed=0
    if (( VIA_NIX )); then
      if [[ "$nix_attr" != "-" ]]; then
        nix_install "$nix_attr" && installed=1
      else
        warn "No Nix attribute declared for $name; skipping in --via-nix mode."
      fi
    else
      # Special-case upstream artifacts first (nerd fonts, starship), then the
      # normal APT-first / source-build resolution.
      local special_rc=0
      install_special_package "$name" || special_rc=$?
      if (( special_rc == 0 )); then
        installed=1
      elif (( special_rc == 127 )); then
        install_package_default "$name" "$apt_name" "$blob" && installed=1
      fi
    fi

    if (( ! installed )); then
      if [[ "$required" == "required" ]]; then
        failed_required+=("$name")
      else
        warn "Optional dependency could not be installed: $name"
      fi
    fi
  done < <(manifest_rows)

  # AI companion backend (Poetry + Poetry env). Treated as optional so a
  # missing backend checkout never fails the desktop install.
  log "AI companion backend"
  install_ai_backend || warn "AI backend install skipped/failed; the AI sidebar will show an error until fixed."

  if ((${#failed_required[@]})); then
    warn "These required dependencies could not be installed: ${failed_required[*]}"
    if (( VIA_NIX )); then
      warn "Check the Nix attribute names against your nixpkgs revision."
    else
      warn "Install them manually or retry with --via-nix."
    fi
    return 1
  fi
  return 0
}

# --- Post-install verification ---------------------------------------------
verify_install() {
  log "Verifying installed components."
  local -a missing=()
  local bin
  for bin in qs quickshell hyprland hyprctl; do
    if have "$bin"; then ok "$bin -> $(command -v "$bin")"; else missing+=("$bin"); fi
  done

  local QS_BIN=""
  if have qs; then QS_BIN="qs"; elif have quickshell; then QS_BIN="quickshell"; fi
  if [[ -n "$QS_BIN" ]]; then
    local probe
    if (( DRY_RUN )); then
      log "Would check that $QS_BIN responds."
    elif probe="$("$QS_BIN" --version 2>&1)"; then
      ok "Quickshell runtime responds: $probe"
    else
      warn "Quickshell did not respond to --version: $probe"
    fi
  fi

  if ((${#missing[@]})); then
    warn "Missing executables on PATH: ${missing[*]}"
  fi

  # AI backend: verify the recorded interpreter can import the bridge.
  local env_file="$HOME/.config/material-hyprland/ai-backend.env"
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    . "$env_file"
    if [[ -n "${AI_GIRLFRIEND_HOME:-}" && -n "${AI_GIRLFRIEND_PYTHON:-}" && -x "${AI_GIRLFRIEND_PYTHON}" ]]; then
      if AI_GIRLFRIEND_HOME="${AI_GIRLFRIEND_HOME}" "${AI_GIRLFRIEND_PYTHON}" -c \
           "import sys; sys.path.insert(0, '${AI_GIRLFRIEND_HOME}'); import src.ai_girlfriend.ui.ipc_server" 2>/dev/null; then
        ok "AI backend bridge imports cleanly: ${AI_GIRLFRIEND_PYTHON}"
      else
        warn "AI backend bridge failed to import with ${AI_GIRLFRIEND_PYTHON}."
      fi
    else
      warn "AI backend env is recorded but AI_GIRLFRIEND_PYTHON is not executable."
    fi
  else
    warn "AI backend not configured (no $env_file); AI sidebar will be disabled."
  fi
}

# --- Config application ----------------------------------------------------
# Install matugen + templates and the kitty / fish / starship configs, then
# generate the initial theme so a brand-new install is already themed.
apply_terminal_config() {
  local CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  local STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/theme/generated"
  local MATUGEN_HOME="$CONFIG_HOME/matugen"
  local KITTY_HOME="$CONFIG_HOME/kitty"
  local FISH_HOME="$CONFIG_HOME/fish"

  local SRC_THEME="$ROOT_DIR/theme"

  if (( DRY_RUN )); then
    log "Would install matugen config: $MATUGEN_HOME/config.toml"
    log "Would install matugen templates into: $MATUGEN_HOME/templates"
    log "Would install kitty config: $KITTY_HOME/kitty.conf"
    log "Would install fish config: $FISH_HOME/config.fish"
    log "Would install starship config: $CONFIG_HOME/starship.toml"
    log "Would install wallpaper/theme script: $CONFIG_HOME/hypr/scripts/apply-theme.sh"
    log "Would generate the initial palette into: $STATE_DIR"
    return 0
  fi

  # --- matugen config + templates -----------------------------------------
  mkdir -p "$MATUGEN_HOME/templates"
  if [[ -f "$MATUGEN_HOME/config.toml" ]] && \
     ! cmp -s "$SRC_THEME/matugen/config.toml" "$MATUGEN_HOME/config.toml"; then
    backup_file "$MATUGEN_HOME/config.toml"
  fi
  install -m 0644 "$SRC_THEME/matugen/config.toml" "$MATUGEN_HOME/config.toml"

  local tpl
  for tpl in "$SRC_THEME"/templates/*; do
    [[ -f "$tpl" ]] || continue
    local dst="$MATUGEN_HOME/templates/$(basename -- "$tpl")"
    if [[ -e "$dst" ]] && ! cmp -s "$tpl" "$dst"; then
      backup_file "$dst"
    fi
    install -m 0644 "$tpl" "$dst"
  done
  ok "Installed matugen config and templates into $MATUGEN_HOME"

  # --- kitty ---------------------------------------------------------------
  mkdir -p "$KITTY_HOME"
  if [[ -e "$KITTY_HOME/kitty.conf" ]] && \
     ! cmp -s "$ROOT_DIR/kitty/kitty.conf" "$KITTY_HOME/kitty.conf"; then
    backup_file "$KITTY_HOME/kitty.conf"
  fi
  install -m 0644 "$ROOT_DIR/kitty/kitty.conf" "$KITTY_HOME/kitty.conf"
  ok "Installed kitty config: $KITTY_HOME/kitty.conf"

  # --- fish ----------------------------------------------------------------
  mkdir -p "$FISH_HOME"
  if [[ -e "$FISH_HOME/config.fish" ]] && \
     ! cmp -s "$ROOT_DIR/fish/config.fish" "$FISH_HOME/config.fish"; then
    backup_file "$FISH_HOME/config.fish"
  fi
  install -m 0644 "$ROOT_DIR/fish/config.fish" "$FISH_HOME/config.fish"
  ok "Installed fish config: $FISH_HOME/config.fish"

  # --- starship (static fallback; generated copy overrides at runtime) -----
  if [[ -e "$CONFIG_HOME/starship.toml" ]] && \
     ! cmp -s "$ROOT_DIR/starship/starship.toml" "$CONFIG_HOME/starship.toml"; then
    backup_file "$CONFIG_HOME/starship.toml"
  fi
  install -m 0644 "$ROOT_DIR/starship/starship.toml" "$CONFIG_HOME/starship.toml"
  ok "Installed starship config: $CONFIG_HOME/starship.toml"

  # --- apply-theme helper (next to the other hypr scripts) -----------------
  mkdir -p "$CONFIG_HOME/hypr/scripts"
  if [[ -e "$CONFIG_HOME/hypr/scripts/apply-theme.sh" ]] && \
     ! cmp -s "$ROOT_DIR/scripts/apply-theme.sh" "$CONFIG_HOME/hypr/scripts/apply-theme.sh"; then
    backup_file "$CONFIG_HOME/hypr/scripts/apply-theme.sh"
  fi
  install -m 0755 "$ROOT_DIR/scripts/apply-theme.sh" "$CONFIG_HOME/hypr/scripts/apply-theme.sh"
  ok "Installed theme helper: $CONFIG_HOME/hypr/scripts/apply-theme.sh"

  # --- generate the initial palette ---------------------------------------
  mkdir -p "$STATE_DIR"
  if have matugen; then
    log "Generating initial Material 3 palette from the current wallpaper."
    if "$ROOT_DIR/scripts/apply-theme.sh" --mode dark; then
      ok "Generated theme files in $STATE_DIR"
    else
      warn "Initial palette generation failed; run scripts/apply-theme.sh manually."
    fi
  else
    warn "matugen not on PATH yet; skipping initial palette generation."
  fi
}

apply_config() {
  if [[ ! -f /etc/linuxmint/info ]]; then
    warn "This project targets Linux Mint/Debian-like systems; continuing cautiously."
  fi

  local CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  local QS_BASE="$CONFIG_HOME/quickshell"
  local QS_LINK="$QS_BASE/material-hyprland"
  local HYPR_DIR="$CONFIG_HOME/hypr"
  local HYPR_MAIN="$HYPR_DIR/hyprland.conf"
  local SRC_HYPR="$ROOT_DIR/hypr"

  [[ -d "$ROOT_DIR/shell" ]] || die "Missing shell directory: $ROOT_DIR/shell"
  [[ -f "$SRC_HYPR/hyprland.conf" ]] \
    || die "Missing Hyprland config: $SRC_HYPR/hyprland.conf"

  if (( DRY_RUN )); then
    log "Would link Quickshell config: $QS_LINK -> $ROOT_DIR/shell"
    log "Would install Hyprland config (.conf modules) into: $HYPR_DIR"
    log "Would source the modular hyprland.conf from $HYPR_MAIN"
    log "Would remove any stale *.lua configs from $HYPR_DIR"
    log "Would install default app preferences into $CONFIG_HOME/material-hyprland"
    log "Would install AI assistant launcher entry: ~/.local/share/applications/material-ai-assistant.desktop"
    log "Would link ai_chat.sh into ~/.local/bin"
    apply_terminal_config
    return 0
  fi

  mkdir -p "$QS_BASE" "$HYPR_DIR"

  # Quickshell: symlink the shell so `qs -c material-hyprland` resolves it.
  if [[ -L "$QS_LINK" || -e "$QS_LINK" ]]; then
    if [[ "$(readlink -f "$QS_LINK" 2>/dev/null || true)" == "$(readlink -f "$ROOT_DIR/shell")" ]]; then
      ok "Quickshell config link already correct."
    else
      die "$QS_LINK exists and is not managed by this installer; move it aside manually."
    fi
  else
    ln -s "$ROOT_DIR/shell" "$QS_LINK"
    ok "Linked $QS_LINK -> $ROOT_DIR/shell"
  fi

  # Hyprland: copy the conf tree (hyprland.conf + hyprland/*.conf modules).
  local rel src dst
  while IFS= read -r -d '' rel; do
    src="$SRC_HYPR/$rel"; dst="$HYPR_DIR/$rel"
    mkdir -p "$(dirname -- "$dst")"
    if [[ -e "$dst" ]] && ! cmp -s "$src" "$dst"; then
      backup_file "$dst"
    fi
    install -m 0644 "$src" "$dst"
  done < <(cd "$SRC_HYPR" && find . -type f -name '*.conf' -print0)

  # Remove stale Lua fragments left behind by earlier revisions of this
  # installer. Hyprland only parses `key = value` config, so any *.lua file
  # pulled in via `source =` fails with "Invalid config line".
  local stale
  for stale in "$HYPR_DIR/hyprland.lua" \
               "$HYPR_DIR"/hyprland/env.lua \
               "$HYPR_DIR"/hyprland/execs.lua \
               "$HYPR_DIR"/hyprland/general.lua \
               "$HYPR_DIR"/hyprland/rules.lua \
               "$HYPR_DIR"/hyprland/shortcuts.lua; do
    if [[ -e "$stale" ]]; then
      backup_file "$stale"
      rm -f "$stale"
      warn "Removed unsupported Lua config: $stale (Hyprland only parses .conf)"
    fi
  done

  # Scripts referenced by keybinds/execs.
  if [[ -d "$SRC_HYPR/scripts" ]]; then
    mkdir -p "$HYPR_DIR/scripts"
    local s
    while IFS= read -r -d '' s; do
      install -m 0755 "$s" "$HYPR_DIR/scripts/$(basename -- "$s")"
    done < <(find "$SRC_HYPR/scripts" -type f ! -path '*/__pycache__/*' -print0)
  fi

  # The copied $HYPR_MAIN already sources the modular *.conf files under
  # $HYPR_DIR/hyprland/. Remove any stale *self-referencing* source lines left
  # behind by earlier revisions of this installer (they caused infinite config
  # recursion) and any stale Lua source lines.
  if [[ -e "$HYPR_MAIN" ]]; then
    if grep -Eq '^[[:space:]]*source[[:space:]]*=[[:space:]]*~/.config/hypr/hyprland\.(conf|lua)[[:space:]]*$' "$HYPR_MAIN"; then
      backup_file "$HYPR_MAIN"
      sed -i -E '\#^[[:space:]]*source[[:space:]]*=[[:space:]]*~/.config/hypr/hyprland\.(conf|lua)[[:space:]]*$#d' "$HYPR_MAIN"
      # Trim a trailing blank line left behind by the removed entry.
      sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$HYPR_MAIN" || true
      warn "Removed stale self/Lua source line from $HYPR_MAIN"
    fi
  fi

  # Default app preferences.
  mkdir -p "$CONFIG_HOME/material-hyprland"
  if [[ ! -e "$CONFIG_HOME/material-hyprland/apps.json" ]]; then
    install -m 0644 "$ROOT_DIR/config/defaults/apps.json" \
      "$CONFIG_HOME/material-hyprland/apps.json"
  fi

  # Desktop entry so the assistant is launchable from the in-shell launcher and
  # any other app menu. `Exec=ai_chat.sh` needs the script on PATH; the hypr
  # scripts land in ~/.config/hypr/scripts, which the profile adds to PATH, but
  # we also install a shim in ~/.local/bin to be safe.
  local apps_dir="$HOME/.local/share/applications"
  mkdir -p "$apps_dir"
  if [[ -f "$ROOT_DIR/config/defaults/applications/material-ai-assistant.desktop" ]]; then
    install -m 0644 "$ROOT_DIR/config/defaults/applications/material-ai-assistant.desktop" \
      "$apps_dir/material-ai-assistant.desktop"
    ok "Installed launcher entry: $apps_dir/material-ai-assistant.desktop"
  fi
  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"
  if [[ -f "$HYPR_DIR/scripts/ai_chat.sh" ]]; then
    ln -sf "$HYPR_DIR/scripts/ai_chat.sh" "$bin_dir/ai_chat.sh"
    ok "Linked ai_chat.sh into $bin_dir"
  fi

  if have hyprland; then
    log "Validating Hyprland config with --verify-config."
    local verify_out
    if verify_out="$(hyprland --verify-config 2>&1)"; then
      if grep -qi 'config error' <<<"$verify_out"; then
        warn "Hyprland reported config errors:"
        printf '%s\n' "$verify_out" >&2
      else
        ok "Hyprland config parses cleanly."
      fi
    else
      warn "hyprland --verify-config failed:"
      printf '%s\n' "$verify_out" >&2
    fi
  else
    warn "hyprland not on PATH yet; skipping config validation."
  fi

  # Terminal stack: matugen + kitty + fish + starship, then initial palette.
  apply_terminal_config

  ok "Configuration applied."
}

# --- Main ------------------------------------------------------------------
if (( ! SKIP_PACKAGES )); then
  install_packages || warn "Package installation completed with errors above."
  verify_install
else
  log "Skipping package installation (--skip-packages)."
fi

if (( ! SKIP_CONFIG )); then
  apply_config
else
  log "Skipping configuration (--skip-config)."
fi

log "Installer finished. Review any warnings above, then run scripts/doctor.sh."
log "No SDDM configuration was changed; keep Cinnamon as your recovery session."
