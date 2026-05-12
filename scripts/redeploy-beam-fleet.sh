#!/usr/bin/env bash
# Redeploy hecate-daemon across beam00..03 WITHOUT wiping data.
#
# Use this for code-only deploys — when the container image changes but
# the on-disk event-store layout is unchanged. Each node is cycled in
# sequence (stop → pull → start) so one beam is always up if the rest
# of the cluster needs to keep quorum.
#
# For schema migrations that require wiping reckon-db directories,
# use scripts/migrate-site-store.sh instead.
#
# Usage:
#   ./scripts/redeploy-beam-fleet.sh          # rolling restart
#   ./scripts/redeploy-beam-fleet.sh --parallel  # stop-all → pull-all → start-all

set -eu

NODES=(beam00 beam01 beam02 beam03)
IMAGE=codeberg.org/hecate-social/hecate-daemon:main
MODE="rolling"

for arg in "$@"; do
    case "$arg" in
        --parallel) MODE="parallel" ;;
        *) echo "Usage: $0 [--parallel]"; exit 1 ;;
    esac
done

ssh_quiet() {
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "rl@${1}.lab" "${2}" 2>&1 \
        | grep -vE "^\*\*|post-quantum|decrypt later|openssh\.com"
}

cycle_node() {
    local n="$1"
    echo "--- ${n}: stop ---"
    ssh_quiet "${n}" 'systemctl --user stop hecate-daemon.service && echo stopped'
    echo "--- ${n}: pull ---"
    ssh_quiet "${n}" "docker pull ${IMAGE}" | tail -3
    echo "--- ${n}: start ---"
    ssh_quiet "${n}" 'systemctl --user start hecate-daemon.service && echo started'
}

case "${MODE}" in
    rolling)
        echo "=== Rolling redeploy (one beam at a time) ==="
        for n in "${NODES[@]}"; do
            cycle_node "${n}"
            echo
        done
        ;;
    parallel)
        echo "=== Parallel redeploy (all beams at once) ==="
        echo "--- stop all ---"
        for n in "${NODES[@]}"; do
            ssh_quiet "${n}" 'systemctl --user stop hecate-daemon.service && echo stopped' &
        done
        wait
        echo "--- pull all ---"
        for n in "${NODES[@]}"; do
            ssh_quiet "${n}" "docker pull ${IMAGE}" | tail -1 &
        done
        wait
        echo "--- start all ---"
        for n in "${NODES[@]}"; do
            ssh_quiet "${n}" 'systemctl --user start hecate-daemon.service && echo started' &
        done
        wait
        ;;
esac

echo
echo "=== Verify cluster health ==="
for n in "${NODES[@]}"; do
    ssh_quiet "${n}" 'systemctl --user is-active hecate-daemon.service' | xargs -I{} echo "${n}: {}"
done
