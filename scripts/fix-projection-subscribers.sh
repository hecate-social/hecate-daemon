#!/bin/bash
# Fix all projection subscribers to convert #event{} records to flat maps
# via projection_event:to_map/1 before passing to project/1.
#
# Bug: ReckonDB sends {events, [#event{}]} records. Subscribers pass raw
# records to project/1 which calls maps:find on a tuple -> badarg crash.
#
# Fix: project(E) -> project(projection_event:to_map(E))

set -euo pipefail

DAEMON_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPS_DIR="${DAEMON_DIR}/apps"

count=0

for f in $(grep -rl ':project(E)' "${APPS_DIR}"/query_*/src/*/on_*_from_pg_project_to_sqlite_*.erl 2>/dev/null); do
    echo "Fixing: ${f#${DAEMON_DIR}/}"
    sed -i 's/:project(E)/:project(projection_event:to_map(E))/g' "$f"
    count=$((count + 1))
done

echo ""
echo "Fixed ${count} projection subscriber files."
echo "All now use projection_event:to_map(E) to convert #event{} records."
