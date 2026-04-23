#!/usr/bin/env bash
#
# Start hecate-daemon + hecate-web in prod-LOCAL mode.
#
# Parallel to dev-all.sh — same ergonomics (foreground, Ctrl+C cleans
# up), different topology:
#
#   dev-all.sh          → ~/.hecate-dev/, port 4445, node hecate_dev,
#                         mesh backend may be inproc (fast CT iteration)
#   prod-all.sh (THIS)  → ~/.hecate-prodlocal/, port 4446, node
#                         hecate_prodlocal, REAL mesh to production
#                         relay fleet + production realm server.
#   Deployed prod       → ~/.hecate/, port 4444, systemd+podman via
#                         hecate-gitops; not touched by either script.
#
# Use this when iterating on mesh-adjacent features (license lifecycle,
# cross-daemon catch-up, rewrap-on-rotation) where the inproc backend
# doesn't exercise enough of the stack.
#
# Usage:
#   ./scripts/prod-all.sh                # start both daemon + web
#   ./scripts/prod-all.sh daemon         # daemon only
#   ./scripts/prod-all.sh web            # web only (assumes daemon running)
#   ./scripts/prod-all.sh --clear        # wipe app data (preserves identity/creds)
#   ./scripts/prod-all.sh --clear daemon # wipe + daemon only
#   ./scripts/prod-all.sh --clear-all    # wipe EVERYTHING incl. identity/creds
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_DIR="$(dirname "$SCRIPT_DIR")"
WEB_DIR="$DAEMON_DIR/../hecate-web"
UI_DIR="$WEB_DIR"
PROD_LOCAL_DATA_DIR="$HOME/.hecate-prodlocal"
WEBKIT_DATA_DIR="$HOME/.local/share/social.hecate.web"
PROD_LOCAL_SOCK="$PROD_LOCAL_DATA_DIR/hecate-daemon/sockets/api.sock"

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

DAEMON_DATA="$PROD_LOCAL_DATA_DIR/hecate-daemon"

# Preserved by --clear. Reckon-DB dirs are NOT preserved — stale
# Khepri state causes slow startup + cross-boot inconsistency.
PRESERVE_DIRS=(
    "$DAEMON_DATA/sqlite"
    "$PROD_LOCAL_DATA_DIR/gitops"
    "$PROD_LOCAL_DATA_DIR/searxng"
)

clear_app_data() {
    echo "=== Clearing prod-local app data (preserving identity/credentials) ==="
    if [ ! -d "$PROD_LOCAL_DATA_DIR" ]; then
        echo "  Nothing to clear"
        echo ""
        return
    fi

    local backup_dir
    backup_dir="$(mktemp -d)"
    for dir in "${PRESERVE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local rel="${dir#"$PROD_LOCAL_DATA_DIR"/}"
            mkdir -p "$backup_dir/$(dirname "$rel")"
            cp -a "$dir" "$backup_dir/$rel"
            echo "  Preserved $rel"
        fi
    done

    rm -rf "$PROD_LOCAL_DATA_DIR"
    echo "  Removed $PROD_LOCAL_DATA_DIR"

    for dir in "${PRESERVE_DIRS[@]}"; do
        local rel="${dir#"$PROD_LOCAL_DATA_DIR"/}"
        if [ -d "$backup_dir/$rel" ]; then
            mkdir -p "$(dirname "$dir")"
            cp -a "$backup_dir/$rel" "$dir"
        fi
    done
    rm -rf "$backup_dir"

    if [ -d "$WEBKIT_DATA_DIR" ]; then
        rm -rf "$WEBKIT_DATA_DIR"
        echo "  Removed $WEBKIT_DATA_DIR (WebKitGTK cache)"
    fi
    echo ""
}

clear_all_data() {
    echo "=== Clearing ALL prod-local data (including identity/credentials) ==="
    if [ -d "$PROD_LOCAL_DATA_DIR" ]; then
        rm -rf "$PROD_LOCAL_DATA_DIR"
        echo "  Removed $PROD_LOCAL_DATA_DIR"
    fi
    if [ -d "$WEBKIT_DATA_DIR" ]; then
        rm -rf "$WEBKIT_DATA_DIR"
        echo "  Removed $WEBKIT_DATA_DIR"
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

cleanup() {
    trap - EXIT INT TERM
    echo ""
    echo "Stopping prod-local processes..."
    jobs -p 2>/dev/null | xargs -r kill 2>/dev/null || true
    pkill -9 -f 'name hecate_prodlocal' 2>/dev/null || true
    for _ in 1 2 3 4 5; do
        pgrep -f 'name hecate_prodlocal' >/dev/null 2>&1 || break
        sleep 0.5
    done
    rm -f "$PROD_LOCAL_SOCK"
    echo "Prod-local stopped."
}

trap cleanup EXIT INT TERM

ensure_searxng() {
    # Shared searxng container — same pattern as dev-all.sh. Uses a
    # distinct container name so it doesn't collide.
    if podman ps --format '{{.Names}}' 2>/dev/null | grep -q '^searxng-prodlocal$'; then
        echo "  SearXNG (prod-local) already running"
        return 0
    fi
    podman rm -f searxng-prodlocal 2>/dev/null || true

    local settings_dst="$PROD_LOCAL_DATA_DIR/searxng/settings.yml"
    mkdir -p "$PROD_LOCAL_DATA_DIR/searxng"

    local settings_src="$PROD_LOCAL_DATA_DIR/gitops/system/searxng/settings.yml"
    local settings_repo="$DAEMON_DIR/../hecate-gitops/quadlet/system/searxng/settings.yml"
    if [ ! -f "$settings_dst" ]; then
        if [ -f "$settings_src" ]; then
            cp "$settings_src" "$settings_dst"
        elif [ -f "$settings_repo" ]; then
            mkdir -p "$PROD_LOCAL_DATA_DIR/gitops/system/searxng"
            cp "$settings_repo" "$settings_dst"
            cp "$settings_repo" "$settings_src"
            echo "  Seeded SearXNG settings from hecate-gitops repo"
        fi
    fi

    if [ ! -f "$settings_dst" ]; then
        echo "  WARN: No SearXNG settings — skipping"
        return 0
    fi

    echo "  Starting SearXNG container (prod-local)..."
    # Different host port from dev (8889 vs 8888) so both can coexist.
    podman run -d --name searxng-prodlocal \
        --network=host \
        -v "$PROD_LOCAL_DATA_DIR/searxng:$PROD_LOCAL_DATA_DIR/searxng:Z" \
        -e "SEARXNG_SETTINGS_PATH=$PROD_LOCAL_DATA_DIR/searxng/settings.yml" \
        -e "GRANIAN_HOST=127.0.0.1" \
        -e "GRANIAN_PORT=8889" \
        docker.io/searxng/searxng:latest >/dev/null

    echo -n "  Waiting for SearXNG on :8889"
    for _ in $(seq 1 15); do
        if curl -sf http://localhost:8889/healthz >/dev/null 2>&1; then
            echo " ready!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo " TIMEOUT (web search will be unavailable)"
}

start_daemon() {
    echo "=== Starting prod-local daemon (real mesh) ==="
    echo "  Refreshing dependencies..."
    rm -f "$DAEMON_DIR/rebar.lock"
    rm -rf "$DAEMON_DIR/_build/default/lib/macula" \
           "$DAEMON_DIR/_build/default/lib/reckon_db" \
           "$DAEMON_DIR/_build/default/lib/evoq" \
           "$DAEMON_DIR/_build/default/lib/reckon_evoq" \
           "$DAEMON_DIR/_build/default/lib/reckon_gater"
    (cd "$DAEMON_DIR" && rebar3 compile 2>&1 | tail -1)

    "$SCRIPT_DIR/prod-start.sh" &
    DAEMON_PID=$!

    echo -n "Waiting for prod-local socket"
    for i in $(seq 1 30); do
        if [ -S "$PROD_LOCAL_SOCK" ]; then
            echo " ready!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo " TIMEOUT"
    echo "ERROR: Prod-local socket not available after 30s"
    return 1
}

start_ui() {
    if [ ! -d "$UI_DIR" ]; then
        echo "ERROR: hecate-web not found at $UI_DIR"
        exit 1
    fi

    echo ""
    echo "=== Starting UI dev server (Vite) pointing at prod-local socket ==="

    if [ ! -d "$UI_DIR/node_modules" ]; then
        echo "  Installing npm dependencies..."
        (cd "$UI_DIR" && npm install)
    fi

    # Vite port is fixed at 1420 in vite.config.ts (strictPort) and
    # tauri.conf.json devUrl. Prod-local and dev can't coexist on one
    # host — stop dev first if it's running.
    (cd "$UI_DIR" && HECATE_SOCKET_PATH="$PROD_LOCAL_SOCK" \
        npm run dev) &
    VITE_PID=$!

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
    return 1
}

start_web() {
    if [ ! -d "$WEB_DIR" ]; then
        echo "ERROR: hecate-web not found at $WEB_DIR"
        exit 1
    fi

    if [ ! -S "$PROD_LOCAL_SOCK" ]; then
        echo "ERROR: Prod-local socket not found at $PROD_LOCAL_SOCK"
        echo "       Start the daemon first: ./scripts/prod-start.sh"
        exit 1
    fi

    if ! ss -tlnp 2>/dev/null | grep -q ":1420 "; then
        start_ui
    else
        echo "  Vite already running on :1420"
    fi

    echo ""
    echo "=== Starting hecate-web (Tauri dev, prod-local socket) ==="
    echo "  Socket: $PROD_LOCAL_SOCK"
    echo ""
    cd "$WEB_DIR"
    HECATE_SOCKET_PATH="$PROD_LOCAL_SOCK" cargo tauri dev
}

case "$MODE" in
    daemon)
        ensure_searxng
        start_daemon
        echo ""
        echo "Prod-local daemon running. Press Ctrl+C to stop."
        wait "$DAEMON_PID"
        ;;
    web)
        start_web
        ;;
    all)
        ensure_searxng
        start_daemon
        start_web
        ;;
esac
