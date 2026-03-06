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
mkdir -p ~/.hecate-dev/config

# Clean stale socket
rm -f ~/.hecate-dev/hecate-daemon/sockets/api.sock

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
echo "  Node:   hecate_dev@$(hostname -s)"
echo ""

exec _build/default/rel/hecate/bin/hecate "$MODE"
