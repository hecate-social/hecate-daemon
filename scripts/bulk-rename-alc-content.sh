#!/bin/bash
# Bulk content update for alc -> cartwheels rename
set -euo pipefail

DAEMON_ROOT="/home/rl/work/github.com/hecate-social/hecate-daemon"
cd "$DAEMON_ROOT"

echo "=== Updating manage_cartwheels files ==="

# Update all .erl files in manage_cartwheels
find apps/manage_cartwheels/src -name "*.erl" -exec sed -i \
    -e 's/manage_alc/manage_cartwheels/g' \
    -e 's/alc_aggregate/cartwheel_aggregate/g' \
    -e 's/project_id/cartwheel_id/g' \
    -e 's/get_project_id/get_cartwheel_id/g' \
    -e 's/ProjectId/CartwheelId/g' \
    {} \;

echo "=== Updating query_cartwheels files ==="

# Update all .erl files in query_cartwheels
find apps/query_cartwheels/src -name "*.erl" -exec sed -i \
    -e 's/query_alc/query_cartwheels/g' \
    -e 's/manage_alc/manage_cartwheels/g' \
    -e 's/projects/cartwheels/g' \
    -e 's/project_id/cartwheel_id/g' \
    -e 's/get_project/get_cartwheel/g' \
    -e 's/list_projects/list_cartwheels/g' \
    -e 's/project_initiated_v1_to/cartwheel_initiated_v1_to/g' \
    -e 's/ProjectId/CartwheelId/g' \
    {} \;

echo "=== Done with content updates ==="
