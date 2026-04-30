#!/usr/bin/env bash
#
# Snapshot each beam's reckon-db (Khepri) data dir before a risky
# operation like cluster join. Rollback: stop daemon, untar, restart.
#
# The tar is taken while the daemon is running — Ra's WAL is
# append-only, so a partial-read snapshot is at worst one WAL frame
# short. Restore-and-recover will reconcile.
#
# Usage:
#   ./scripts/snapshot-beam-khepri.sh             # all four
#   ./scripts/snapshot-beam-khepri.sh beam00      # one
#
set -eu

DEFAULT_NODES=(beam00 beam01 beam02 beam03)
DATA_DIR='/fast/.hecate/hecate-daemon/reckon-db'
STAMP=$(date -u +%Y%m%d-%H%M%S)

if [ "$#" -gt 0 ]; then
    NODES=("$@")
else
    NODES=("${DEFAULT_NODES[@]}")
fi

for node in "${NODES[@]}"; do
    host="${node}.lab"
    out="/home/rl/hecate-khepri-pre-cluster-${STAMP}.tgz"
    echo "=== ${host} → ${out} ==="
    ssh -o ConnectTimeout=5 "rl@${host}" \
        "tar -czf '${out}' -C / '${DATA_DIR#/}' && ls -lh '${out}'" \
        2>&1 | grep -vE '^\*\*|post-quantum|decrypt later|openssh\.com'
    echo
done
