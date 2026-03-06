#!/usr/bin/env bash
#
# Start hecate-daemon + hecate-web in dev mode.
#
# Daemon: ~/.hecate-dev/ data dir, foreground in background
# Web:    Tauri dev mode, pointed at dev daemon socket
#
# Usage:
#   ./scripts/dev-all.sh          # start both
#   ./scripts/dev-all.sh daemon   # daemon only (same as dev-start.sh)
#   ./scripts/dev-all.sh web      # web only (assumes daemon running)
#
# Ctrl+C stops the web (foreground). Daemon is stopped via trap.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_DIR="$(dirname "$SCRIPT_DIR")"
WEB_DIR="$DAEMON_DIR/../hecate-web"
DEV_SOCK="$HOME/.hecate-dev/hecate-daemon/sockets/api.sock"

MODE="${1:-all}"
DAEMON_PID=""

cleanup() {
    if [ -n "$DAEMON_PID" ] && kill -0 "$DAEMON_PID" 2>/dev/null; then
        echo ""
        echo "Stopping dev daemon (PID $DAEMON_PID)..."
        kill "$DAEMON_PID" 2>/dev/null || true
        wait "$DAEMON_PID" 2>/dev/null || true
        rm -f "$DEV_SOCK"
        echo "Dev daemon stopped."
    fi
}
trap cleanup EXIT

start_daemon() {
    echo "=== Starting dev daemon ==="
    "$SCRIPT_DIR/dev-start.sh" &
    DAEMON_PID=$!

    # Wait for socket
    echo -n "Waiting for daemon socket"
    for i in $(seq 1 30); do
        if [ -S "$DEV_SOCK" ]; then
            echo " ready!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo " TIMEOUT"
    echo "ERROR: Daemon socket not available after 30s"
    return 1
}

start_web() {
    if [ ! -d "$WEB_DIR" ]; then
        echo "ERROR: hecate-web not found at $WEB_DIR"
        exit 1
    fi

    if [ ! -S "$DEV_SOCK" ]; then
        echo "ERROR: Dev daemon socket not found at $DEV_SOCK"
        echo "       Start the daemon first: ./scripts/dev-start.sh"
        exit 1
    fi

    echo ""
    echo "=== Starting hecate-web (Tauri dev) ==="
    echo "  Socket: $DEV_SOCK"
    echo ""
    cd "$WEB_DIR"
    HECATE_SOCKET_PATH="$DEV_SOCK" npm run tauri dev
}

case "$MODE" in
    daemon)
        start_daemon
        echo ""
        echo "Daemon running. Press Ctrl+C to stop."
        wait "$DAEMON_PID"
        ;;
    web)
        start_web
        ;;
    all)
        start_daemon
        start_web
        ;;
    *)
        echo "Usage: $0 [all|daemon|web]"
        exit 1
        ;;
esac
