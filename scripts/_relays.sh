#!/usr/bin/env bash
#
# Shared helper: resolve the realm's station ("relay") fleet.
#
# Single source of truth is the macula-demo topology:
#   macula-demo/topologies/$MACULA_TOPOLOGY/generated/realm-relays.txt
# (a single comma-separated line of https://<station>:4433 URLs).
#
# resolve_relays <hecate-daemon-project-dir>
#   -> echoes the comma-separated MACULA_RELAYS value.
#
# Looks for macula-demo as a sibling checkout:
#   <project-dir>/../../macula-internal/macula-demo
# (the work/github.com workspace layout). Override with MACULA_DEMO_DIR.
# Falls back to the current Greater-Leuven list if the topology file
# isn't reachable (e.g. on a box where macula-demo isn't checked out).

# Current Greater-Leuven io.macula station fleet — keep in sync with
# macula-demo/topologies/eu/be/leuven/generated/realm-relays.txt.
# (Used only as the offline fallback; the topology file wins.)
_FALLBACK_RELAYS="https://station-be-leuven-centrum.macula.io:4433,https://station-be-leuven-gasthuisberg.macula.io:4433,https://station-be-leuven-haasrode.macula.io:4433,https://station-be-leuven-kessel-lo.macula.io:4433,https://station-be-leuven-vaartkom.macula.io:4433,https://station-be-leuven-wilsele.macula.io:4433,https://station-be-leuven-arenberg.macula.io:4433,https://station-be-leuven-wijgmaal.macula.io:4433,https://station-be-leuven-bertem.macula.io:4433,https://station-be-leuven-linden.macula.io:4433"

resolve_relays() {
    local project_dir="$1"
    local topology="${MACULA_TOPOLOGY:-eu/be/leuven}"
    local demo_dir="${MACULA_DEMO_DIR:-$project_dir/../../macula-internal/macula-demo}"
    local relays_file="$demo_dir/topologies/$topology/generated/realm-relays.txt"

    if [ -f "$relays_file" ]; then
        # Strip whitespace/newlines; the file is one comma-separated line.
        tr -d '[:space:]' < "$relays_file"
    else
        printf '%s' "$_FALLBACK_RELAYS"
    fi
}
