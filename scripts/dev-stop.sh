#!/usr/bin/env bash
#
# Stop the dev hecate-daemon.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

export VMARGS_PATH="$PROJECT_DIR/config/dev.vm.args"

_build/default/rel/hecate/bin/hecate stop 2>/dev/null || true

# Clean socket
rm -f ~/.hecate-dev/hecate-daemon/sockets/api.sock

echo "Dev daemon stopped."
