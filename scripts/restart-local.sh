#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="${REPO_DIR}/_build/default/rel/hecate"
RELEASE_DATA_DIR="${RELEASE_DIR}/data"
REPO_DATA_DIR="${REPO_DIR}/data"
SOCKET_PATH="${HOME}/.hecate/hecate-daemon/sockets/api.sock"
PIPE_DIR="/tmp/erl_pipes/hecate@$(cat /etc/hostname 2>/dev/null || echo localhost)"
LOG_DIR="${RELEASE_DIR}/log"
NODE_NAME="hecate"
HEALTH_PORT=8180
CLEAN=false

# Parse flags
for arg in "$@"; do
    case "${arg}" in
        --clean) CLEAN=true ;;
        *) echo "Unknown flag: ${arg}"; echo "Usage: $0 [--clean]"; exit 1 ;;
    esac
done

echo "==> Stopping existing daemon..."
"${RELEASE_DIR}/bin/hecate" stop 2>/dev/null || true
sleep 1

# Kill order: parents first (stop respawning), then children
# heart processes are just "heart -pid NNNN" — no "hecate" in cmdline
echo "==> Killing parent processes (heart, run_erl)..."
killall -9 heart 2>/dev/null || true
killall -9 run_erl 2>/dev/null || true
sleep 1

echo "==> Killing child processes (beam.smp)..."
killall -9 beam.smp 2>/dev/null || true
pkill -9 -f '/bin/sh.*hecate.*daemon' 2>/dev/null || true
sleep 1

# Brute force: kill anything on the health port
for attempt in 1 2 3 4 5; do
    PID=$(ss -tlnp 2>/dev/null | grep ":${HEALTH_PORT}" | grep -oP 'pid=\K[0-9]+' || true)
    if [ -z "${PID}" ]; then
        break
    fi
    echo "    killing pid ${PID} on port ${HEALTH_PORT} (attempt ${attempt})..."
    kill -9 "${PID}" 2>/dev/null || true
    sleep 1
done

# Wait for zombies to be reaped
for i in 1 2 3; do
    if ss -tlnp 2>/dev/null | grep -q ":${HEALTH_PORT}"; then
        echo "    waiting for port ${HEALTH_PORT} to free (attempt $i)..."
        sleep 2
    else
        break
    fi
done

echo "==> Unregistering from epmd..."
epmd -stop "${NODE_NAME}" 2>/dev/null || true
sleep 1

# Verify port is free
if ss -tlnp 2>/dev/null | grep -q ":${HEALTH_PORT}"; then
    echo "!!! ERROR: port ${HEALTH_PORT} still in use — cannot start daemon"
    ss -tlnp | grep ":${HEALTH_PORT}"
    exit 1
fi

echo "==> Cleaning stale files..."
rm -f "${SOCKET_PATH}"
rm -rf "${PIPE_DIR}"
rm -f "${LOG_DIR}"/erlang.log.*

# Ensure socket directory exists (user home, no sudo needed)
mkdir -p "$(dirname "${SOCKET_PATH}")"

if [ "${CLEAN}" = true ]; then
    echo "==> Wiping ALL data (ReckonDB + SQLite)..."
    rm -rf "${RELEASE_DATA_DIR}"
    rm -rf "${REPO_DATA_DIR}"
    echo "    removed ${RELEASE_DATA_DIR}"
    echo "    removed ${REPO_DATA_DIR}"
fi

echo "==> Building release..."
cd "${REPO_DIR}"
rebar3 release 2>&1 | tail -3

echo "==> Starting daemon..."
"${RELEASE_DIR}/bin/hecate" daemon

echo "==> Waiting for socket (up to 30s)..."
for i in $(seq 1 30); do
    if [ -S "${SOCKET_PATH}" ]; then
        if curl -sf -m 2 --unix-socket "${SOCKET_PATH}" http://d/health >/dev/null 2>&1; then
            echo "==> Daemon healthy!"
            curl -s --unix-socket "${SOCKET_PATH}" http://d/health 2>&1
            echo ""
            exit 0
        fi
    fi
    sleep 1
done

echo "==> WARNING: Daemon may not be fully ready yet."
echo "    Check logs: tail -100 ${LOG_DIR}/erlang.log.1"
echo "    Check epmd: epmd -names"
echo "    Check procs: ps aux | grep beam.smp"
exit 1
