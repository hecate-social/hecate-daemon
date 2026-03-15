#!/bin/bash
## Fix event to_map/1 functions: convert binary map keys to atom keys.
##
## Root cause: evoq extracts event_type via maps:get(event_type, Event, undefined)
## (atom key). Events using <<"event_type">> (binary key) get silently dropped
## by the event router — no handlers, no projections, no logs.
##
## This script converts <<"key">> => patterns to key => in ALL _v1.erl event
## files that have a to_map function.
##
## Safe because:
## - from_map uses get_value/get_field which handles both atom and binary keys
## - Aggregate apply_event already has dual patterns (atom + binary)
## - Only map keys change; values remain binary (<<"visionary_initiated_v1">>)

set -euo pipefail

APPS_DIR="$(cd "$(dirname "$0")/.." && pwd)/apps"
CHANGED=0
SKIPPED=0

echo "=== Fixing binary keys -> atom keys in event to_map functions ==="
echo ""

# Find all _v1.erl files that have to_map AND use binary keys
while IFS= read -r f; do
    if grep -q 'to_map(' "$f" && grep -q '<<"[a-z_]*">> =>' "$f"; then
        sed -i 's/<<"\([a-z_]*\)">> =>/\1 =>/g' "$f"
        echo "  FIXED: ${f#$APPS_DIR/}"
        CHANGED=$((CHANGED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done < <(find "$APPS_DIR" -name '*_v1.erl' -type f)

echo ""
echo "=== Fixed $CHANGED files, skipped $SKIPPED (no binary keys or no to_map) ==="
echo ""
echo "Next: cd $(dirname "$APPS_DIR") && rebar3 compile"
