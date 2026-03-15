#!/usr/bin/env bash
#
# Start hecate-daemon + hecate-web in dev mode.
#
# Daemon: ~/.hecate-dev/ data dir, foreground in background
# Web:    Tauri dev mode, pointed at dev daemon socket
#
# Usage:
#   ./scripts/dev-all.sh                # start both
#   ./scripts/dev-all.sh daemon         # daemon only (same as dev-start.sh)
#   ./scripts/dev-all.sh web            # web only (assumes daemon running)
#   ./scripts/dev-all.sh --clear        # wipe app data (preserves identity/credentials)
#   ./scripts/dev-all.sh --clear daemon # wipe app data, then daemon only
#   ./scripts/dev-all.sh --clear-all    # wipe EVERYTHING including identity/credentials
#
# Ctrl+C stops the web (foreground). Daemon is stopped via trap.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_DIR="$(dirname "$SCRIPT_DIR")"
WEB_DIR="$DAEMON_DIR/../hecate-web"
UI_DIR="$WEB_DIR"
DEV_DATA_DIR="$HOME/.hecate-dev"
WEBKIT_DATA_DIR="$HOME/.local/share/social.hecate.web"
DEV_SOCK="$DEV_DATA_DIR/hecate-daemon/sockets/api.sock"

CLEAR=false
CLEAR_ALL=false
MODE="all"

for arg in "$@"; do
    case "$arg" in
        --clear-all) CLEAR_ALL=true ;;
        --clear) CLEAR=true ;;
        daemon|web|all) MODE="$arg" ;;
        *) echo "Usage: $0 [--clear|--clear-all] [all|daemon|web]"; exit 1 ;;
    esac
done

DAEMON_DATA="$DEV_DATA_DIR/hecate-daemon"

# Directories that hold identity and credentials — preserved by --clear
PRESERVE_DIRS=(
    "$DAEMON_DATA/sqlite"
    "$DAEMON_DATA/reckon-db/settings"
    "$DAEMON_DATA/reckon-db/realm_memberships"
)

clear_app_data() {
    echo "=== Clearing app data (preserving identity/credentials) ==="
    if [ ! -d "$DEV_DATA_DIR" ]; then
        echo "  Nothing to clear"
        echo ""
        return
    fi

    # Back up preserved dirs to temp
    local backup_dir
    backup_dir="$(mktemp -d)"
    for dir in "${PRESERVE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local rel="${dir#"$DEV_DATA_DIR"/}"
            mkdir -p "$backup_dir/$(dirname "$rel")"
            cp -a "$dir" "$backup_dir/$rel"
            echo "  Preserved $rel"
        fi
    done

    # Wipe everything
    rm -rf "$DEV_DATA_DIR"
    echo "  Removed $DEV_DATA_DIR"

    # Restore preserved dirs
    for dir in "${PRESERVE_DIRS[@]}"; do
        local rel="${dir#"$DEV_DATA_DIR"/}"
        if [ -d "$backup_dir/$rel" ]; then
            mkdir -p "$(dirname "$dir")"
            cp -a "$backup_dir/$rel" "$dir"
        fi
    done
    rm -rf "$backup_dir"

    # Clear WebKitGTK cache
    if [ -d "$WEBKIT_DATA_DIR" ]; then
        rm -rf "$WEBKIT_DATA_DIR"
        echo "  Removed $WEBKIT_DATA_DIR (WebKitGTK localStorage/cache)"
    fi
    echo ""
}

clear_all_data() {
    echo "=== Clearing ALL dev data (including identity/credentials) ==="
    if [ -d "$DEV_DATA_DIR" ]; then
        rm -rf "$DEV_DATA_DIR"
        echo "  Removed $DEV_DATA_DIR"
    fi
    if [ -d "$WEBKIT_DATA_DIR" ]; then
        rm -rf "$WEBKIT_DATA_DIR"
        echo "  Removed $WEBKIT_DATA_DIR (WebKitGTK localStorage/cache)"
    fi
    echo ""
}

if [ "$CLEAR_ALL" = true ]; then
    clear_all_data
elif [ "$CLEAR" = true ]; then
    clear_app_data
fi
DAEMON_PID=""
VITE_PID=""

cleanup_vite() {
    if [ -n "$VITE_PID" ] && kill -0 "$VITE_PID" 2>/dev/null; then
        echo ""
        echo "Stopping Vite dev server (PID $VITE_PID)..."
        kill "$VITE_PID" 2>/dev/null || true
        wait "$VITE_PID" 2>/dev/null || true
    fi
}

cleanup_all() {
    cleanup_vite
    if [ -n "$DAEMON_PID" ] && kill -0 "$DAEMON_PID" 2>/dev/null; then
        echo ""
        echo "Stopping dev daemon (PID $DAEMON_PID)..."
        kill "$DAEMON_PID" 2>/dev/null || true
        wait "$DAEMON_PID" 2>/dev/null || true
        rm -f "$DEV_SOCK"
        echo "Dev daemon stopped."
    fi
}

# Only clean up on explicit Ctrl+C, NOT on EXIT.
# cargo tauri dev exits and restarts on rebuilds — EXIT trap kills everything.
trap cleanup_all INT TERM

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

start_ui() {
    if [ ! -d "$UI_DIR" ]; then
        echo "ERROR: hecate-web not found at $UI_DIR"
        exit 1
    fi

    echo ""
    echo "=== Starting UI dev server (Vite) ==="

    # Install npm deps if missing
    if [ ! -d "$UI_DIR/node_modules" ]; then
        echo "  Installing npm dependencies..."
        (cd "$UI_DIR" && npm install)
    fi

    # Start Vite dev server in background (pass socket path for API proxy)
    (cd "$UI_DIR" && HECATE_SOCKET_PATH="$DEV_SOCK" npm run dev) &
    VITE_PID=$!

    # Wait for Vite to be ready on port 1420
    echo -n "  Waiting for Vite on :1420"
    for i in $(seq 1 30); do
        if ss -tlnp 2>/dev/null | grep -q ":1420 "; then
            echo " ready!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo " TIMEOUT"
    echo "ERROR: Vite dev server not available after 30s"
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

    # Start UI dev server (Vite) if not already running
    if ! ss -tlnp 2>/dev/null | grep -q ":1420 "; then
        start_ui
    else
        echo "  Vite already running on :1420"
    fi

    echo ""
    echo "=== Starting hecate-web (Tauri dev) ==="
    echo "  Socket: $DEV_SOCK"
    echo ""
    cd "$WEB_DIR"
    HECATE_SOCKET_PATH="$DEV_SOCK" cargo tauri dev
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
esac
