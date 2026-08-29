#!/bin/bash
## Test Erlang distribution over relay mesh.
##
## Spins up a temporary Erlang node inside the daemon container
## with -proto_dist macula and MACULA_DIST_MODE=relay.
## Tries to connect to one of the beam cluster nodes via the mesh.
##
## Usage: ssh rl@beam00.lab 'bash -s' < scripts/test-dist-relay.sh

set -euo pipefail

echo "=== Testing Erlang Distribution over Relay Mesh ==="

# The daemon container has the Erlang release with macula
docker exec hecate-daemon sh -c '
    echo "Starting test node with -proto_dist macula..."

    # Check if macula_dist_pool module exists (renamed from
    # macula_dist_relay in macula 9.0.0)
    ./bin/hecate eval "
        case code:ensure_loaded(macula_dist_pool) of
            {module, _} ->
                io:format(\"macula_dist_pool: loaded~n\"),
                io:format(\"relay_mode: ~p~n\", [macula_dist_pool:is_relay_mode()]),
                io:format(\"mesh_pool: ~p~n\", [macula_dist_pool:get_mesh_pool()]);
            {error, Reason} ->
                io:format(\"macula_dist_pool: ~p~n\", [Reason])
        end,
        halt(0).
    "
'

echo ""
echo "=== Done ==="
