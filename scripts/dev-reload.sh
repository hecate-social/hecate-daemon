#!/usr/bin/env bash
#
# Hot-reload compiled modules into running dev daemon.
#
# Usage:
#   ./scripts/dev-reload.sh              # compile + reload all changed modules
#   ./scripts/dev-reload.sh module_name  # reload specific module
#
# No daemon restart needed. Compiles with rebar3, then loads
# the new beam files into the running VM via the release script.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REL_BIN="$PROJECT_DIR/_build/default/rel/hecate/bin/hecate"

cd "$PROJECT_DIR"

echo "Compiling..."
rebar3 compile 2>&1 | tail -3

if [ $# -gt 0 ]; then
    # Reload specific module
    MODULE="$1"
    echo "Reloading module: $MODULE"
    $REL_BIN eval "code:purge($MODULE), code:load_file($MODULE)."
else
    # Find all recently compiled beam files and reload them
    echo "Finding changed modules..."
    CHANGED=$(find _build/default/lib/*/ebin -name '*.beam' -newer _build/default/rel/hecate/releases/*/start.boot 2>/dev/null | \
        sed 's|.*/||; s|\.beam||' | sort -u)

    if [ -z "$CHANGED" ]; then
        echo "No changes to reload."
        exit 0
    fi

    COUNT=$(echo "$CHANGED" | wc -l)
    echo "Reloading $COUNT module(s)..."

    # Build reload command
    RELOAD_CMD=""
    for MOD in $CHANGED; do
        RELOAD_CMD="${RELOAD_CMD}code:purge($MOD), code:load_file($MOD), "
    done
    RELOAD_CMD="${RELOAD_CMD}ok."

    $REL_BIN eval "$RELOAD_CMD"
    echo "Done. Modules reloaded:"
    echo "$CHANGED" | sed 's/^/  /'
fi
