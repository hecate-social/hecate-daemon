#!/usr/bin/env bash
#
# Quick smoke test against the dev daemon socket.
#
set -euo pipefail

SOCK=~/.hecate-dev/hecate-daemon/sockets/api.sock

if [ ! -S "$SOCK" ]; then
    echo "ERROR: Dev socket not found at $SOCK"
    echo "       Start the dev daemon first: ./scripts/dev-start.sh"
    exit 1
fi

echo "=== Health ==="
curl -s --unix-socket "$SOCK" http://localhost/health | python3 -m json.tool

echo ""
echo "=== Launcher Layout ==="
curl -s --unix-socket "$SOCK" http://localhost/api/launcher/layout | python3 -m json.tool

echo ""
echo "=== Launcher Entries ==="
curl -s --unix-socket "$SOCK" http://localhost/api/launcher/entries | python3 -m json.tool

echo ""
echo "=== Installed Plugins ==="
curl -s --unix-socket "$SOCK" http://localhost/api/plugins | python3 -m json.tool
