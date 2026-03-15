#!/usr/bin/env bash
# Add evoq_command/evoq_event behaviours to all command and event modules.
#
# Commands: {verb}_{subject}_v1.erl — get -behaviour(evoq_command) + command_type/0
# Events:  {subject}_{past_verb}_v1.erl — get -behaviour(evoq_event) + event_type/0
#
# Identification: commands export new/1 + to_map/1 + from_map/1 and have
# imperative names. Events export new/1 + to_map/1 and have past-tense names.
# We use the presence of a record matching the module name to confirm.
#
# Strategy: Insert behaviour + export + callback after the -module() line.

set -euo pipefail

APPS_DIR="$(cd "$(dirname "$0")/.." && pwd)/apps"
MODIFIED=0
SKIPPED=0

add_behaviour() {
    local file="$1"
    local behaviour="$2"   # evoq_command or evoq_event
    local callback_name="$3"  # command_type or event_type

    # Extract module name from -module(xxx).
    local modname
    modname=$(grep -oP '(?<=-module\()[\w]+(?=\))' "$file")

    # Skip if behaviour already declared
    if grep -q "behaviour($behaviour)" "$file"; then
        return 1
    fi

    # Insert -behaviour after -module line
    sed -i "/-module($modname)\./a\\\\n-behaviour($behaviour)." "$file"

    # Add export for callback — insert after first -export line
    local first_export_line
    first_export_line=$(grep -n "^-export" "$file" | head -1 | cut -d: -f1)
    sed -i "${first_export_line}a\\-export([${callback_name}/0])." "$file"

    # Add callback function before the first function definition
    # Find the line of the first function (after all -export, -record, -type, -define, -include)
    # We insert just before the first exported function (new/1 typically)
    local new_line
    new_line=$(grep -n "^new(" "$file" | head -1 | cut -d: -f1)
    if [ -n "$new_line" ]; then
        sed -i "${new_line}i\\${callback_name}() -> ${modname}.\n" "$file"
    fi

    MODIFIED=$((MODIFIED + 1))
    echo "  ✓ $file"
    return 0
}

echo "=== Adding evoq_command behaviour to command modules ==="

# Command modules: exported new/1 + from_map/1 + to_map/1, name is verb_subject_v1
# Heuristic: module name starts with a verb (install, remove, upgrade, initiate, etc.)
# AND has a record matching the module name
COMMAND_PATTERNS=(
    "install_*_v1.erl"
    "upgrade_*_v1.erl"
    "remove_*_v1.erl"
    "initiate_*_v1.erl"
    "archive_*_v1.erl"
    "start_*_v1.erl"
    "stop_*_v1.erl"
    "confirm_*_v1.erl"
    "cancel_*_v1.erl"
    "complete_*_v1.erl"
    "activate_*_v1.erl"
    "deactivate_*_v1.erl"
    "extract_*_v1.erl"
    "update_*_v1.erl"
    "announce_*_v1.erl"
    "publish_*_v1.erl"
    "retract_*_v1.erl"
    "amend_*_v1.erl"
    "draft_*_v1.erl"
    "accept_*_v1.erl"
    "reject_*_v1.erl"
    "buy_*_v1.erl"
    "grant_*_v1.erl"
    "revoke_*_v1.erl"
    "abandon_*_v1.erl"
    "expire_*_v1.erl"
    "renew_*_v1.erl"
    "track_*_v1.erl"
    "initialize_*_v1.erl"
    "register_*_v1.erl"
    "unregister_*_v1.erl"
    "reorganize_*_v1.erl"
)

for pattern in "${COMMAND_PATTERNS[@]}"; do
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        # Must have -record matching module name (confirms it's a command, not a handler)
        modname=$(grep -oP '(?<=-module\()[\w]+(?=\))' "$file")
        if grep -q "^-record($modname," "$file"; then
            add_behaviour "$file" "evoq_command" "command_type" || SKIPPED=$((SKIPPED + 1))
        fi
    done < <(find "$APPS_DIR" -path "*/src/*" -name "$pattern" 2>/dev/null)
done

echo ""
echo "=== Adding evoq_event behaviour to event modules ==="

# Event modules: name is subject_past_verb_v1 (past tense: installed, removed, upgraded, etc.)
EVENT_PATTERNS=(
    "*_installed_v1.erl"
    "*_upgraded_v1.erl"
    "*_removed_v1.erl"
    "*_initiated_v1.erl"
    "*_archived_v1.erl"
    "*_started_v1.erl"
    "*_stopped_v1.erl"
    "*_confirmed_v1.erl"
    "*_cancelled_v1.erl"
    "*_completed_v1.erl"
    "*_activated_v1.erl"
    "*_deactivated_v1.erl"
    "*_extracted_v1.erl"
    "*_updated_v1.erl"
    "*_announced_v1.erl"
    "*_published_v1.erl"
    "*_retracted_v1.erl"
    "*_amended_v1.erl"
    "*_drafted_v1.erl"
    "*_accepted_v1.erl"
    "*_rejected_v1.erl"
    "*_bought_v1.erl"
    "*_granted_v1.erl"
    "*_revoked_v1.erl"
    "*_abandoned_v1.erl"
    "*_expired_v1.erl"
    "*_renewed_v1.erl"
    "*_tracked_v1.erl"
    "*_initialized_v1.erl"
    "*_registered_v1.erl"
    "*_unregistered_v1.erl"
    "*_reorganized_v1.erl"
    "*_detected_v1.erl"
    "*_reported_v1.erl"
)

for pattern in "${EVENT_PATTERNS[@]}"; do
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        # Must have -record matching module name (confirms it's an event, not a handler/projection)
        modname=$(grep -oP '(?<=-module\()[\w]+(?=\))' "$file")
        if grep -q "^-record($modname," "$file"; then
            add_behaviour "$file" "evoq_event" "event_type" || SKIPPED=$((SKIPPED + 1))
        fi
    done < <(find "$APPS_DIR" -path "*/src/*" -name "$pattern" 2>/dev/null)
done

echo ""
echo "=== Summary ==="
echo "Modified: $MODIFIED"
echo "Skipped (already had behaviour): $SKIPPED"
