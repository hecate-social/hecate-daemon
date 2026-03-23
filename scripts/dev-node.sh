#!/usr/bin/env bash
#
# Start a numbered dev node for mesh testing.
#
# Usage:
#   ./scripts/dev-node.sh 0    # Node hecate_dev0 on port 4450, data in ~/.hecate-dev0/
#   ./scripts/dev-node.sh 1    # Node hecate_dev1 on port 4451, data in ~/.hecate-dev1/
#   ...
#   ./scripts/dev-node.sh 6    # Node hecate_dev6 on port 4456, data in ~/.hecate-dev6/
#
# Each node gets:
#   - Unique BEAM node name (hecate_devN)
#   - Unique data dir (~/.hecate-devN/)
#   - Unique ports (API: 4450+N, health: 8190+N, QUIC: 9450+N)
#   - Unique MRI identity (mri:agent:io.macula/hecate-devN)
#   - Connects to boot.macula.io and joins io.macula realm
#   - LLM disabled (keeps nodes lightweight)
#
# Run your main dev daemon in another terminal (./scripts/dev-all.sh daemon),
# then start extra nodes here to test mesh discovery and communication.
#
set -euo pipefail

NODE_NUM="${1:?Usage: $0 <0-6>}"

if [[ ! "$NODE_NUM" =~ ^[0-6]$ ]]; then
    echo "ERROR: Node number must be 0-6"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEV_HOME="$HOME/.hecate-dev${NODE_NUM}"
DEV_DATA="$DEV_HOME/hecate-daemon"
DEV_SOCK="$DEV_DATA/sockets/api.sock"
NODE_NAME="hecate_dev${NODE_NUM}"
API_PORT=$((4450 + NODE_NUM))
HEALTH_PORT=$((8190 + NODE_NUM))
QUIC_PORT=$((9450 + NODE_NUM))

cd "$PROJECT_DIR"

# Ensure data dirs
mkdir -p "$DEV_DATA"/{sqlite,reckon-db,sockets,run,connectors,registry}
mkdir -p "$DEV_HOME"/{config,gitops/system}

# Source secrets if available (API keys for LLM providers, etc.)
DEV_ENV="$HOME/.hecate-dev/gitops/system/hecate-daemon.env"
if [ -f "$DEV_ENV" ]; then
    set -a; . "$DEV_ENV"; set +a
fi

# Override socket path
export HECATE_SOCKET_PATH="$DEV_SOCK"

# Use standard EPMD for dev node discovery (not custom port range)
unset ERL_DIST_PORT

# Clean stale socket
rm -f "$DEV_SOCK"

# Kill stale BEAM if this node name is already running
if pgrep -f "sname $NODE_NAME" > /dev/null 2>&1; then
    echo "Killing stale $NODE_NAME..."
    pkill -f "sname $NODE_NAME" || true
    sleep 2
fi

# Build if needed (shared across all nodes)
if [ ! -d "_build/default/rel/hecate" ]; then
    echo "Building release..."
    rebar3 release
fi

# Point at the node-specific config
export RELX_CONFIG_PATH="$PROJECT_DIR/config/dev${NODE_NUM}.sys.config"
export VMARGS_PATH="$PROJECT_DIR/config/dev${NODE_NUM}.vm.args"

NODE_HOST="$(cat /etc/hostname 2>/dev/null || uname -n)"

echo ""
echo "=== Hecate Dev Node $NODE_NUM ==="
echo "  Node:     ${NODE_NAME}@${NODE_HOST}"
echo "  Data:     $DEV_DATA"
echo "  Socket:   $DEV_SOCK"
echo "  API:      http://127.0.0.1:${API_PORT}"
echo "  Health:   http://127.0.0.1:${HEALTH_PORT}"
echo "  QUIC:     :${QUIC_PORT}"
echo "  Identity: mri:agent:io.macula/hecate-dev${NODE_NUM}"
echo ""
echo "  Test mesh: curl http://127.0.0.1:${API_PORT}/api/mesh/status"
echo "  Test health: curl http://127.0.0.1:${API_PORT}/api/health"
echo ""

exec _build/default/rel/hecate/bin/hecate foreground
