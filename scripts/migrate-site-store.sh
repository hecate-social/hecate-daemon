#!/usr/bin/env bash
# Migration: wipe site_store on beam00-03 and restart with fresh :main image.
#
# Why:
#   commit cfc1b95 changes lanmachine-* stream_id from lanmachine-{MAC}
#   to lanmachine-{MAC}-{Observer}. Old streams are orphaned under the
#   new keying scheme. A coordinated stop/wipe/restart across all cluster
#   members is required — leaving any node up would re-seed the wiped
#   nodes with old-format streams via Khepri/Ra snapshot transfer.
#
# Sequence:
#   1. Stop hecate-daemon on all 4 beams (in parallel)
#   2. Wipe /fast/.hecate/hecate-daemon/reckon-db/site on each (sudo)
#   3. docker pull codeberg.org/hecate-social/hecate-daemon:main
#   4. Start hecate-daemon on each
#
# Usage:
#   ./scripts/migrate-site-store.sh
#
# Safe to re-run. Stopping an already-stopped service and wiping an
# already-wiped path are both no-ops.

set -eu

NODES=(beam00 beam01 beam02 beam03)
SITE_DIR=/fast/.hecate/hecate-daemon/reckon-db/site
IMAGE=codeberg.org/hecate-social/hecate-daemon:main

ssh_quiet() {
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "rl@${1}.lab" "${2}" 2>&1 \
        | grep -vE "^\*\*|post-quantum|decrypt later|openssh\.com"
}

echo "=== Step 1: stop all hecate-daemon services ==="
for n in "${NODES[@]}"; do
    echo "--- ${n} ---"
    ssh_quiet "${n}" 'systemctl --user stop hecate-daemon.service && echo stopped'
done

echo
echo "=== Step 2: wipe site_store data dir (sudo) ==="
for n in "${NODES[@]}"; do
    echo "--- ${n} ---"
    ssh_quiet "${n}" "sudo rm -rf ${SITE_DIR} && echo wiped"
done

echo
echo "=== Step 3: pull fresh :main image ==="
for n in "${NODES[@]}"; do
    echo "--- ${n} ---"
    ssh_quiet "${n}" "docker pull ${IMAGE}" | tail -3
done

echo
echo "=== Step 4: start all hecate-daemon services ==="
for n in "${NODES[@]}"; do
    echo "--- ${n} ---"
    ssh_quiet "${n}" 'systemctl --user start hecate-daemon.service && echo started'
done

echo
echo "=== Done. Verify cluster health: ==="
for n in "${NODES[@]}"; do
    ssh_quiet "${n}" 'systemctl --user is-active hecate-daemon.service' | xargs -I{} echo "${n}: {}"
done
