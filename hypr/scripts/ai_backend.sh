#!/usr/bin/env bash
# ~/.config/hypr/scripts/ai_backend.sh
# Start (or restart) the AI companion FastAPI backend on localhost:8080.
#
# The Quickshell AI sidebar itself talks to the core over a JSON/stdio bridge
# (AiBridge.qml spawns `python -m src.ai_girlfriend.ui.ipc_server` on demand),
# so the drawer works without this server. This script instead keeps the
# standalone HTTP backend (`src/ai_girlfriend/main.py`) running for other
# clients / manual testing, exactly what `invoke serve` does inside the backend
# checkout. It is autostarted from execs.conf via exec-once.
#
# Behaviour:
#   * sources ~/.config/material-hyprland/ai-backend.env for AI_GIRLFRIEND_HOME
#     / AI_GIRLFRIEND_PYTHON (written by scripts/install.sh),
#   * is idempotent — if something already answers on the port it does nothing,
#   * self-heals a missing/unpopulated venv by falling back to `poetry run`,
#   * logs to ~/.cache/material-hyprland/ai-backend.log.
#
# Usage: ai_backend.sh [--port N] [--host H] [--restart] [--check]
#   --check    only report whether the server answers, then exit.

set -uo pipefail

QS_HOST="localhost"
QS_PORT="8080"
LOG_DIR="$HOME/.cache/material-hyprland"
LOG_FILE="$LOG_DIR/ai-backend.log"
ENV_FILE="$HOME/.config/material-hyprland/ai-backend.env"

log()  { printf '\033[1;34m[ai-backend]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ai-backend]\033[0m %s\n' "$*" >&2; }

RESTART=0
CHECK_ONLY=0
while (($#)); do
    case "$1" in
        --host) QS_HOST="${2:?--host needs a value}"; shift 2 ;;
        --port) QS_PORT="${2:?--port needs a value}"; shift 2 ;;
        --restart) RESTART=1; shift ;;
        --check)   CHECK_ONLY=1; shift ;;
        *) warn "unknown argument: $1"; shift ;;
    esac
done

# --- Locate the backend ----------------------------------------------------
[[ -f "$ENV_FILE" ]] && . "$ENV_FILE"
BACKEND_DIR="${AI_GIRLFRIEND_HOME:-$HOME/Projects/AI-girlfriend/AI_girlfriend_chat}"
PYTHON_BIN="${AI_GIRLFRIEND_PYTHON:-$BACKEND_DIR/.venv/bin/python}"

# --- Health check ----------------------------------------------------------
# Prefer curl; fall back to python so we work on a minimal session too.
port_up() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsS --max-time 2 "http://$QS_HOST:$QS_PORT/" >/dev/null 2>&1
        return $?
    fi
    "$PYTHON_BIN" - "$QS_HOST" "$QS_PORT" <<'PY' >/dev/null 2>&1
import socket, sys
s = socket.socket()
s.settimeout(2)
s.connect((sys.argv[1], int(sys.argv[2])))
s.close()
PY
}

if [[ "$CHECK_ONLY" == 1 ]]; then
    if port_up; then log "backend answers on http://$QS_HOST:$QS_PORT"; exit 0; fi
    warn "backend NOT answering on http://$QS_HOST:$QS_PORT"; exit 1
fi

if port_up; then
    log "AI backend already running on http://$QS_HOST:$QS_PORT; nothing to do."
    exit 0
fi

# --- Validate the checkout -------------------------------------------------
if [[ ! -d "$BACKEND_DIR" ]]; then
    warn "Backend checkout not found: $BACKEND_DIR"
    warn "Set AI_GIRLFRIEND_HOME or re-run scripts/install.sh."
    exit 1
fi

mkdir -p "$LOG_DIR"

# --- Optionally restart (kill a stale pid if we recorded one) --------------
PID_FILE="$LOG_DIR/ai-backend.pid"
if [[ "$RESTART" == 1 && -f "$PID_FILE" ]]; then
    old="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
        log "Stopping previous backend (pid $old)…"
        kill "$old" 2>/dev/null || true
        sleep 0.5
    fi
fi

# --- Pick the launcher: in-venv uvicorn, else `poetry run uvicorn` ----------
UVICORN_ARGS=(src.ai_girlfriend.main:app --host "$QS_HOST" --port "$QS_PORT")
cd "$BACKEND_DIR" || { warn "cannot cd into $BACKEND_DIR"; exit 1; }

if [[ -x "$BACKEND_DIR/.venv/bin/uvicorn" ]]; then
    CMD=("$BACKEND_DIR/.venv/bin/uvicorn" "${UVICORN_ARGS[@]}")
elif command -v poetry >/dev/null 2>&1; then
    CMD=(poetry run uvicorn "${UVICORN_ARGS[@]}")
else
    warn "Neither .venv/uvicorn nor poetry is available; run 'poetry install'."
    exit 1
fi

log "Starting FastAPI backend: ${CMD[*]}"
# Detach so it survives this script and the Hyprland exec-once shell.
setsid "${CMD[@]}" >>"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

# --- Wait briefly for it to come up ---------------------------------------
for _ in $(seq 1 40); do
    if port_up; then
        log "AI backend is up on http://$QS_HOST:$QS_PORT (log: $LOG_FILE)."
        exit 0
    fi
    sleep 0.25
done

warn "Backend did not answer in time. See $LOG_FILE:"
tail -n 20 "$LOG_FILE" 2>/dev/null >&2 || true
exit 1
