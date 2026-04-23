#!/usr/bin/env bash
#
# Force-refresh the hecate-daemon container image on each beam node.
#
# Why this exists:
#   Watchtower polls ghcr.io every ~60s and auto-updates containers it
#   manages. But `hecate-daemon` on beam nodes is managed by
#   systemd --user (with ExecStartPre=/usr/bin/docker rm -f), so
#   Watchtower can't stop/recreate it — the systemd unit races back
#   up. Watchtower logs show:
#     "Error: image is being used by running container ..."
#   Stubs (hecate-copenhagen, hecate-hamburg, light-stubs) are plain
#   docker and get updated fine.
#
# This script does what Watchtower can't: docker pull, then
# systemctl --user restart hecate-daemon, which re-runs
# `ExecStartPre=docker rm -f` and starts a fresh container with the
# new image.
#
# Idempotent — no-op if the image hasn't changed.
#
# Usage:
#   ./scripts/update-beam-daemon-image.sh            # all four beams
#   ./scripts/update-beam-daemon-image.sh beam00     # one node
#
set -eu

DEFAULT_NODES=(beam00 beam01 beam02 beam03)
IMAGE='ghcr.io/hecate-social/hecate-daemon:main'

if [ "$#" -gt 0 ]; then
    NODES=("$@")
else
    NODES=("${DEFAULT_NODES[@]}")
fi

for node in "${NODES[@]}"; do
    host="${node}.lab"
    echo "=== ${host} ==="

    ssh -o ConnectTimeout=5 "rl@${host}" \
        "docker pull -q ${IMAGE} && systemctl --user restart hecate-daemon && sleep 2 && docker inspect hecate-daemon --format 'image={{.Image}} started={{.State.StartedAt}}'" \
        2>&1 | grep -vE '^\*\*|post-quantum|decrypt later|openssh\.com'
    echo
done
