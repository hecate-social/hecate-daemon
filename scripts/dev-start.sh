#!/usr/bin/env bash
#
# Start hecate-daemon in dev mode.
#
# Uses:
#   - Data dir: ~/.hecate-dev/hecate-daemon/
#   - Socket:   ~/.hecate-dev/hecate-daemon/sockets/api.sock
#   - Node:     hecate_dev@hostname (no cluster conflict)
#   - No heartbeat (crashes stay crashed for debugging)
#
# Usage:
#   ./scripts/dev-start.sh          # foreground (Ctrl+C to stop)
#   ./scripts/dev-start.sh console  # interactive shell
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Ensure dev data directory exists
mkdir -p ~/.hecate-dev/hecate-daemon/{sqlite,reckon-db,sockets,run,connectors}
mkdir -p ~/.hecate-dev/{config,gitops/system,searxng}

# Source dev environment (mirrors production EnvironmentFile)
DEV_ENV="$HOME/.hecate-dev/gitops/system/hecate-daemon.env"
REPO_ENV="$PROJECT_DIR/../hecate-gitops/quadlet/system/hecate-daemon.env"
if [ ! -f "$DEV_ENV" ] && [ -f "$REPO_ENV" ]; then
    cp "$REPO_ENV" "$DEV_ENV"
    echo "Seeded $DEV_ENV from hecate-gitops repo"
fi
if [ -f "$DEV_ENV" ]; then
    echo "Sourcing $DEV_ENV"
    set -a
    # shellcheck source=/dev/null
    . "$DEV_ENV"
    set +a
fi

# Override socket path for dev (env file has REPLACE_ME placeholder)
export HECATE_SOCKET_PATH="$HOME/.hecate-dev/hecate-daemon/sockets/api.sock"

# MACULA_BOOTSTRAP_PEERS is intentionally NOT set here.
# hecate_mesh_client handles its own connection to boot.macula.io via macula:connect().
# Setting MACULA_BOOTSTRAP_PEERS causes macula_root to create a SECOND peer connection
# to the same endpoint, competing for the boot server's rate limit budget (5/10s).
# With two connections retrying simultaneously, neither can establish reliably.

# MaxMind GeoIP: extract license key from GeoIP.conf if not already set
if [ -z "${MAXMIND_LICENSE_KEY:-}" ] && [ -f "$HOME/.config/maxmind/GeoIP.conf" ]; then
    MAXMIND_LICENSE_KEY="$(grep '^LicenseKey' "$HOME/.config/maxmind/GeoIP.conf" | awk '{print $2}')"
    export MAXMIND_LICENSE_KEY
    echo "Loaded MAXMIND_LICENSE_KEY from ~/.config/maxmind/GeoIP.conf"
fi

# Use standard EPMD for dev node discovery (not custom port range)
unset ERL_DIST_PORT

# Clean stale socket
rm -f "$HECATE_SOCKET_PATH"

# Kill stale BEAM holding the dev node name (exact match, don't kill dev0/dev1/etc)
if pgrep -f 'sname hecate_dev ' > /dev/null 2>&1; then
    echo "Killing stale hecate_dev BEAM process..."
    pkill -f 'sname hecate_dev ' || true
    sleep 2
fi

# Build release with dev config
echo "Building dev release..."
rebar3 release

MODE="${1:-foreground}"

# Override sys.config and vm.args for dev
export RELX_CONFIG_PATH="$PROJECT_DIR/config/dev.sys.config"
export VMARGS_PATH="$PROJECT_DIR/config/dev.vm.args"

echo ""
echo "=== Hecate Dev ==="
echo "  Data:   ~/.hecate-dev/hecate-daemon/"
echo "  Socket: ~/.hecate-dev/hecate-daemon/sockets/api.sock"
echo "  VMARGS: $VMARGS_PATH"
echo "  SYSCONFIG: $RELX_CONFIG_PATH"
echo "  Contents:"
head -2 "$VMARGS_PATH"
echo ""

exec _build/default/rel/hecate/bin/hecate "$MODE"
