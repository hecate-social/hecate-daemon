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
if [ -f "$DEV_ENV" ]; then
    echo "Sourcing $DEV_ENV"
    set -a
    # shellcheck source=/dev/null
    . "$DEV_ENV"
    set +a
fi

# Clean stale socket
rm -f ~/.hecate-dev/hecate-daemon/sockets/api.sock

# Kill stale BEAM/epmd holding the dev node name
if pgrep -f 'sname hecate_dev' > /dev/null 2>&1; then
    echo "Killing stale hecate_dev BEAM process..."
    pkill -f 'sname hecate_dev' || true
    sleep 2
fi

# Build release with dev config
echo "Building dev release..."
rebar3 release

MODE="${1:-foreground}"

# Override sys.config and vm.args for dev
export RELX_CONFIG_PATH="$PROJECT_DIR/config/dev.sys.config"
export VMARGS_PATH="$PROJECT_DIR/config/dev.vm.args"

NODE_HOST="$(cat /etc/hostname 2>/dev/null || uname -n)"

echo ""
echo "=== Hecate Dev ==="
echo "  Data:   ~/.hecate-dev/hecate-daemon/"
echo "  Socket: ~/.hecate-dev/hecate-daemon/sockets/api.sock"
echo "  Node:   hecate_dev@${NODE_HOST}"
echo ""

exec _build/default/rel/hecate/bin/hecate "$MODE"
