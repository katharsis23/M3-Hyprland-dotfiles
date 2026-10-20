#!/usr/bin/env bash
# ~/.config/hypr/scripts/ai_backend.sh
# Run the AI companion FastAPI backend (uvicorn) on localhost:7865 exactly once
# per Hyprland session.
#
# The Quickshell AI sidebar talks to the core over a JSON/stdio bridge (spawned
# on demand by AiBridge.qml), so the drawer works without this server. This
# script keeps the *standalone* HTTP backend (`src.ai_girlfriend.main:app`,
# the same thing `invoke serve` starts) running for the REST API / manual
# testing, and — with `--serve` — as a small supervisor that restarts uvicorn
# if it dies.
#
# It is launched once from execs.conf (`exec-once = ai_backend.sh --serve`) so
# there is a single, visible process tree per session instead of a detached
# uvicorn that loses its log and never comes back after a crash.
#
# Behaviour:
#   * sources ~/.config/material-hyprland/ai-backend.env for AI_GIRLFRIEND_HOME
#     / AI_GIRLFRIEND_PYTHON (written by scripts/install.sh),
#   * is idempotent — if something already answers on the port it does nothing,
#   * self-heals a missing/unpopulated venv by falling back to `poetry run`,
#   * logs to ~/.cache/material-hyprland/ai-backend.log.
#
# Usage: ai_backend.sh [--port N] [--host H] [--restart|--serve|--stop|--check]
#   (default)  start uvicorn detached if the port is free, then exit
#   --serve    foreground supervisor: (re)start uvicorn, restart it on exit,
#              until told to stop (this is what execs.conf uses)
#   --restart  stop a running backend and start a fresh detached one
#   --stop     stop the backend started by --serve/--restart
#   --check    only report whether the server answers, then exit

set -uo pipefail

QS_HOST="localhost"
QS_PORT="7865"
LOG_DIR="$HOME/.cache/material-hyprland"
LOG_FILE="$LOG_DIR/ai-backend.log"
PID_FILE="$LOG_DIR/ai-backend.pid"
ENV_FILE="$HOME/.config/material-hyprland/ai-backend.env"

log()  { printf '\033[1;34m[ai-backend]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ai-backend]\033[0m %s\n' "$*" >&2; }

MODE="start"
while (($#)); do
    case "$1" in
        --host) QS_HOST="${2:?--host needs a value}"; shift 2 ;;
        --port) QS_PORT="${2:?--port needs a value}"; shift 2 ;;
        --restart) MODE="restart"; shift ;;
        --serve)   MODE="serve";   shift ;;
        --stop)    MODE="stop";    shift ;;
        --check)   MODE="check";   shift ;;
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

if [[ "$MODE" == "check" ]]; then
    if port_up; then log "backend answers on http://$QS_HOST:$QS_PORT"; exit 0; fi
    warn "backend NOT answering on http://$QS_HOST:$QS_PORT"; exit 1
fi

mkdir -p "$LOG_DIR"

# Stop the process recorded in the pid file; also reap a --serve supervisor.
stop_backend() {
    local old
    old="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
        log "Stopping backend (pid $old)…"
        kill "$old" 2>/dev/null || true
        for _ in $(seq 1 20); do kill -0 "$old" 2>/dev/null || break; sleep 0.1; done
        kill -9 "$old" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    pkill -f "ai_backend.sh --serve" 2>/dev/null || true
}

if [[ "$MODE" == "stop" ]]; then
    stop_backend
    log "Backend stopped."
    exit 0
fi

# --- Validate the checkout -------------------------------------------------
if [[ ! -d "$BACKEND_DIR" ]]; then
    warn "Backend checkout not found: $BACKEND_DIR"
    warn "Set AI_GIRLFRIEND_HOME or re-run scripts/install.sh."
    exit 1
fi

# --- Pick the launcher: in-venv uvicorn, else `poetry run uvicorn` ----------
UVICORN_ARGS=(src.ai_girlfriend.main:app --host "$QS_HOST" --port "$QS_PORT")

resolve_cmd() {
    if [[ -x "$BACKEND_DIR/.venv/bin/uvicorn" ]]; then
        CMD=("$BACKEND_DIR/.venv/bin/uvicorn" "${UVICORN_ARGS[@]}")
    elif command -v poetry >/dev/null 2>&1; then
        CMD=(poetry run uvicorn "${UVICORN_ARGS[@]}")
    else
        warn "Neither .venv/uvicorn nor poetry is available; run 'poetry install'."
        return 1
    fi
}

# --- Default / --restart: start a detached backend if the port is free ------
if [[ "$MODE" == "start" || "$MODE" == "restart" ]]; then
    if [[ "$MODE" == "restart" ]]; then
        stop_backend
    elif port_up; then
        log "AI backend already running on http://$QS_HOST:$QS_PORT; nothing to do."
        exit 0
    fi

    resolve_cmd || exit 1
    cd "$BACKEND_DIR" || { warn "cannot cd into $BACKEND_DIR"; exit 1; }

    log "Starting FastAPI backend: ${CMD[*]}"
    # Detach so it survives this script. The `--serve` supervisor is the
    # preferred way to keep it alive; this path is for manual invocations.
    setsid "${CMD[@]}" >>"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"

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
fi

# --- --serve: supervision loop --------------------------------------------
# Runs uvicorn as a child, restarts it if it exits (crash, OOM, reload, manual
# kill), and exits cleanly when the supervisor is terminated by Hyprland logout.
if [[ "$MODE" == "serve" ]]; then
    # Never run two supervisors: a second one would race on the port.
    if port_up; then
        log "AI backend already running on http://$QS_HOST:$QS_PORT; supervisor idle."
        exit 0
    fi
    resolve_cmd || exit 1
    cd "$BACKEND_DIR" || { warn "cannot cd into $BACKEND_DIR"; exit 1; }

    echo $$ >"$PID_FILE"
    log "Supervising FastAPI backend on http://$QS_HOST:$QS_PORT (log: $LOG_FILE)."

    child=0
    stopping=0
    # Forward TERM/INT so a logout stops the child instead of orphaning it.
    trap 'stopping=1; [[ $child -ne 0 ]] && kill "$child" 2>/dev/null' TERM INT

    while [[ "$stopping" -eq 0 ]]; do
        log "Starting: ${CMD[*]}"
        "${CMD[@]}" >>"$LOG_FILE" 2>&1 &
        child=$!
        # `wait` returns early when signalled; loop until the child exits.
        wait "$child"
        rc=$?
        child=0
        [[ "$stopping" -eq 1 ]] && break
        warn "uvicorn exited (code $rc); restarting in 1s (--stop to stop)…"
        sleep 1
        # Re-resolve in case the venv/poetry changed between restarts.
        resolve_cmd || { warn "backend launcher vanished; giving up."; break; }
    done

    rm -f "$PID_FILE"
    log "Supervisor stopped."
    exit 0
fi
