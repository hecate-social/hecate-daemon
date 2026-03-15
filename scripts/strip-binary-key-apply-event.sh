#!/bin/bash
## Remove binary-key apply_event clauses from aggregates.
##
## Aggregates have dual patterns for backward compat:
##   apply_event(#{<<"event_type">> := <<"foo_v1">>} = E, S) -> ...;
##   apply_event(#{event_type := <<"foo_v1">>} = E, S)       -> ...;
##
## Since we're not in production, delete the binary-key lines.
## Also cleans up binary-key execute/get_command_type patterns.

set -euo pipefail

APPS_DIR="$(cd "$(dirname "$0")/.." && pwd)/apps"
CHANGED=0

echo "=== Stripping binary-key apply_event lines from aggregates ==="
echo ""

for f in $(grep -rl 'apply_event(#{<<"event_type">>' "$APPS_DIR" --include='*_aggregate.erl'); do
    # Delete lines that match apply_event(#{<<"event_type">> := ...
    sed -i '/^apply_event(#{<<"event_type">> :=/d' "$f"
    echo "  FIXED: ${f#$APPS_DIR/}"
    CHANGED=$((CHANGED + 1))
done

echo ""

# Also strip binary-key get_command_type patterns
echo "=== Stripping binary-key get_command_type lines ==="
for f in $(grep -rl 'get_command_type(#{<<"command_type">>' "$APPS_DIR" --include='*.erl' 2>/dev/null); do
    sed -i '/^get_command_type(#{<<"command_type">>/d' "$f"
    echo "  FIXED: ${f#$APPS_DIR/}"
done

echo ""
echo "=== Cleaned $CHANGED aggregate files ==="
echo ""
echo "Next: cd $(dirname "$APPS_DIR") && rebar3 compile"
