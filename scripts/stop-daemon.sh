#!/usr/bin/env bash
set -euo pipefail

PID_FILE="${HOME}/.hecate/daemon.pid"

if [ ! -f "${PID_FILE}" ]; then
    echo "No PID file found at ${PID_FILE}"
    exit 0
fi

PID=$(cat "${PID_FILE}")

if kill -0 "${PID}" 2>/dev/null; then
    echo "Stopping daemon (PID ${PID})..."
    kill "${PID}"
    echo "Daemon stopped."
else
    echo "Daemon not running (stale PID ${PID})."
    rm -f "${PID_FILE}"
fi
