#!/bin/bash
# Rename manage_alc -> manage_cartwheels and query_alc -> query_cartwheels
# Also renames project -> cartwheel in module names, events, and code

set -euo pipefail

DAEMON_ROOT="/home/rl/work/github.com/hecate-social/hecate-daemon"
cd "$DAEMON_ROOT"

echo "=== Phase 1: Renaming manage_alc -> manage_cartwheels ==="

# Step 1: Rename the directory
git mv apps/manage_alc apps/manage_cartwheels

# Step 2: Rename app files
git mv apps/manage_cartwheels/src/manage_alc.app.src apps/manage_cartwheels/src/manage_cartwheels.app.src
git mv apps/manage_cartwheels/src/manage_alc_app.erl apps/manage_cartwheels/src/manage_cartwheels_app.erl
git mv apps/manage_cartwheels/src/manage_alc_sup.erl apps/manage_cartwheels/src/manage_cartwheels_sup.erl
git mv apps/manage_cartwheels/src/alc_aggregate.erl apps/manage_cartwheels/src/cartwheel_aggregate.erl

# Step 3: Rename initiate_project spoke -> initiate_cartwheel
git mv apps/manage_cartwheels/src/initiate_project apps/manage_cartwheels/src/initiate_cartwheel
git mv apps/manage_cartwheels/src/initiate_cartwheel/initiate_project_v1.erl apps/manage_cartwheels/src/initiate_cartwheel/initiate_cartwheel_v1.erl
git mv apps/manage_cartwheels/src/initiate_cartwheel/project_initiated_v1.erl apps/manage_cartwheels/src/initiate_cartwheel/cartwheel_initiated_v1.erl
git mv apps/manage_cartwheels/src/initiate_cartwheel/maybe_initiate_project.erl apps/manage_cartwheels/src/initiate_cartwheel/maybe_initiate_cartwheel.erl

echo "=== Phase 2: Renaming query_alc -> query_cartwheels ==="

# Step 1: Rename the directory
git mv apps/query_alc apps/query_cartwheels

# Step 2: Rename app files
git mv apps/query_cartwheels/src/query_alc.app.src apps/query_cartwheels/src/query_cartwheels.app.src
git mv apps/query_cartwheels/src/query_alc_app.erl apps/query_cartwheels/src/query_cartwheels_app.erl
git mv apps/query_cartwheels/src/query_alc_sup.erl apps/query_cartwheels/src/query_cartwheels_sup.erl
git mv apps/query_cartwheels/src/query_alc_store.erl apps/query_cartwheels/src/query_cartwheels_store.erl
git mv apps/query_cartwheels/src/query_alc_subscriber.erl apps/query_cartwheels/src/query_cartwheels_subscriber.erl

# Step 3: Rename project -> cartwheel related files in query_cartwheels
git mv apps/query_cartwheels/src/list_projects apps/query_cartwheels/src/list_cartwheels
git mv apps/query_cartwheels/src/list_cartwheels/list_projects.erl apps/query_cartwheels/src/list_cartwheels/list_cartwheels.erl
git mv apps/query_cartwheels/src/get_project apps/query_cartwheels/src/get_cartwheel
git mv apps/query_cartwheels/src/get_cartwheel/get_project.erl apps/query_cartwheels/src/get_cartwheel/get_cartwheel.erl

# Rename projections that reference "project"
git mv apps/query_cartwheels/src/project_initiated_v1_to_projects.erl apps/query_cartwheels/src/cartwheel_initiated_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/discovery_started_v1_to_projects.erl apps/query_cartwheels/src/discovery_started_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/discovery_completed_v1_to_projects.erl apps/query_cartwheels/src/discovery_completed_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/phase_transitioned_v1_to_projects.erl apps/query_cartwheels/src/phase_transitioned_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/architecture_started_v1_to_projects.erl apps/query_cartwheels/src/architecture_started_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/plan_approved_v1_to_projects.erl apps/query_cartwheels/src/plan_approved_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/architecture_completed_v1_to_projects.erl apps/query_cartwheels/src/architecture_completed_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/testing_started_v1_to_projects.erl apps/query_cartwheels/src/testing_started_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/skeleton_created_v1_to_projects.erl apps/query_cartwheels/src/skeleton_created_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/testing_completed_v1_to_projects.erl apps/query_cartwheels/src/testing_completed_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/deployment_started_v1_to_projects.erl apps/query_cartwheels/src/deployment_started_v1_to_cartwheels.erl
git mv apps/query_cartwheels/src/deployment_completed_v1_to_projects.erl apps/query_cartwheels/src/deployment_completed_v1_to_cartwheels.erl

echo "=== Phase 3: Updating rebar.config files ==="

# Note: Content updates are done separately via sed

echo "=== Done with file renames ==="
echo "Next: Update module declarations and references in all .erl files"
