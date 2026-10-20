#!/usr/bin/env bash
# ~/.config/hypr/scripts/ai_chat.sh
# Open the AI assistant drawer, starting everything it needs first.
#
# What it guarantees, in order:
#   1. The Python backend location is known (AI_GIRLFRIEND_HOME / .env file).
#   2. The interpreter exists and the bridge module imports (sanity check).
#   3. Quickshell is running (it spawns the backend via AiBridge on demand).
#   4. The Left AI drawer is toggled through the shell's IPC handler.
#
# The backend itself is launched by the shell (shell/qt/core/AiBridge.qml) as a
# child process over JSON/stdio, so this wrapper only needs to make sure the
# pieces are in place and then ask the shell to show the drawer.
#
# Usage: ai_chat.sh [--check]
#   --check   verify the backend prerequisites and exit (no UI toggle).

set -uo pipefail

QS_CONFIG="material-hyprland/qt"
LOG_DIR="$HOME/.cache/material-hyprland"
ENV_FILE="$HOME/.config/material-hyprland/ai-backend.env"

log()  { printf '\033[1;34m[ai]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ai]\033[0m %s\n' "$*" >&2; }

# --- 1. Locate the backend -------------------------------------------------
# install.sh records both vars here; sourcing it is harmless if absent.
[[ -f "$ENV_FILE" ]] && . "$ENV_FILE"

BACKEND_DIR="${AI_GIRLFRIEND_HOME:-$HOME/Projects/AI-girlfriend/AI_girlfriend_chat}"
PYTHON_BIN="${AI_GIRLFRIEND_PYTHON:-$BACKEND_DIR/.venv/bin/python}"

# --- 2. Verify interpreter + bridge import ---------------------------------
check_backend() {
    local ok=0
    if [[ ! -d "$BACKEND_DIR" ]]; then
        warn "Backend checkout not found: $BACKEND_DIR"
        warn "Set AI_GIRLFRIEND_HOME or re-run scripts/install.sh."
        ok=1
    fi
    if [[ ! -x "$PYTHON_BIN" ]]; then
        warn "Python interpreter not found: $PYTHON_BIN"
        warn "Run scripts/install.sh (poetry install) or set AI_GIRLFRIEND_PYTHON."
        ok=1
    fi
    if (( ! ok )) && ! "$PYTHON_BIN" - "$BACKEND_DIR" <<'PY' 2>/dev/null
import sys
sys.path.insert(0, sys.argv[1])
import importlib
importlib.import_module("src.ai_girlfriend.ui.ipc_server")
PY
    then
        warn "Bridge module failed to import with $PYTHON_BIN"
        warn "Try: (cd \"$BACKEND_DIR\" && poetry install)"
        ok=1
    fi
    return "$ok"
}

if ! check_backend; then
    # Still let the user see the failure state inside the drawer if the shell
    # is already running, but skip the toggle when nothing can work at all.
    exit 1
fi

if [[ "${1:-}" == "--check" ]]; then
    log "Backend OK: $BACKEND_DIR"
    log "Interpreter: $PYTHON_BIN"
    exit 0
fi

# --- 3. Ensure the shell is running ---------------------------------------
# The AI sidebar is a *drawer inside the main shell* — it must never spawn a
# second Quickshell instance. We therefore only fall back to launching the
# shell when no shell is running *at all*.
#
# NB: the Nix package runs a process literally named ``quickshell-wrapped-<ver>``
# (``qs`` is a shim), so ``pgrep -x quickshell`` never matches and this script
# used to launch a duplicate shell on every SUPER+ALT+L. The authoritative check
# is the shell's own IPC endpoint: if ``qs -c <config> ipc show shell`` answers,
# exactly one shell with our config is up and we just toggle the drawer.
shell_ipc_up() {
    qs -c "$QS_CONFIG" ipc show shell >/dev/null 2>&1
}

if ! shell_ipc_up; then
    # Only start the shell if *no* Quickshell is running (avoid duplicates when
    # it is alive but momentarily not answering IPC).
    if pgrep -f '[q]uickshell' >/dev/null 2>&1; then
        log "Quickshell is running but IPC is not ready yet; waiting…"
    else
        log "Quickshell not running; launching the shell…"
        mkdir -p "$LOG_DIR"
        setsid qs -c "$QS_CONFIG" >>"$LOG_DIR/quickshell.log" 2>&1 &
    fi
    # Give the shell a moment to register its IPC target before calling it.
    for _ in $(seq 1 50); do
        shell_ipc_up && break
        sleep 0.1
    done
fi

# --- 4. Toggle the AI drawer ----------------------------------------------
log "Opening the assistant drawer."
qs -c "$QS_CONFIG" ipc call shell toggleAiSidebar
