#!/usr/bin/env bash
#
# run_all.sh — launch both services together:
#   - demucs_svc (separation API)  on :8001
#   - web app    (main:app)        on :8000
#
# Ctrl-C (or any exit) stops both. Logs stream to the console, prefixed.
#
set -euo pipefail

cd "$(dirname "$0")"

WEB_HOST="${WEB_HOST:-0.0.0.0}"
WEB_PORT="${WEB_PORT:-8000}"
DEMUCS_HOST="${DEMUCS_HOST:-0.0.0.0}"
DEMUCS_PORT="${DEMUCS_PORT:-8001}"

pids=()

cleanup() {
    echo
    echo "[run_all] shutting down..."
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
    echo "[run_all] stopped."
}
trap cleanup EXIT INT TERM

echo "[run_all] starting demucs_svc on ${DEMUCS_HOST}:${DEMUCS_PORT}"
uv run uvicorn demucs_svc.app:app \
    --host "${DEMUCS_HOST}" --port "${DEMUCS_PORT}" \
    2>&1 | sed -u 's/^/[demucs] /' &
pids+=($!)

echo "[run_all] starting web app on ${WEB_HOST}:${WEB_PORT}"
uv run uvicorn main:app \
    --host "${WEB_HOST}" --port "${WEB_PORT}" --reload \
    --reload-exclude 'logs/*' --reload-exclude '*.log' --reload-exclude '*.log.*' \
    2>&1 | sed -u 's/^/[web]    /' &
pids+=($!)

echo "[run_all] both services running. Press Ctrl-C to stop."
wait
