#!/usr/bin/env bash
#
# Poke POST /api/mesh/activate on each beam node so its hecate-daemon
# reconnects to the mesh using the realm credentials it already has on
# disk.
#
# Why this exists:
#   Beam daemons join the realm *by inheritance* — an attended node
#   (laptop) does OAuth, the membership event replicates via the
#   Erlang cluster, and hecate_cluster_provision obtains a per-node
#   cert. After reboots / network blips / activator crashes, mesh can
#   end up in "local mode" with valid creds but no active client. This
#   script just nudges it back up.
#
# Usage:
#   ./scripts/activate-beam-mesh.sh              # all four beams
#   ./scripts/activate-beam-mesh.sh beam00       # one node
#   ./scripts/activate-beam-mesh.sh beam00 beam02
#
set -eu

DEFAULT_NODES=(beam00 beam01 beam02 beam03)
SOCKET_PATH='/fast/.hecate/hecate-daemon/sockets/api.sock'

if [ "$#" -gt 0 ]; then
    NODES=("$@")
else
    NODES=("${DEFAULT_NODES[@]}")
fi

for node in "${NODES[@]}"; do
    host="${node}.lab"
    echo "=== ${host} ==="
    # -f: fail on 4xx/5xx so the loop surfaces errors; -sS: quiet but show errors.
    # Unix socket path is interpreted by the REMOTE shell, hence single-quoted in SOCKET_PATH.
    if ssh -o ConnectTimeout=5 "rl@${host}" \
        "curl -fsS --unix-socket ${SOCKET_PATH} -X POST http://localhost/api/mesh/activate" \
        2>&1 | grep -vE '^\*\*|post-quantum|decrypt later|openssh\.com'; then
        echo
    else
        echo "  (activate failed — check daemon status + realm membership)"
    fi
done
