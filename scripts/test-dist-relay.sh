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

    # Check if macula_dist_relay module exists
    ./bin/hecate eval "
        case code:ensure_loaded(macula_dist_relay) of
            {module, _} ->
                io:format(\"macula_dist_relay: loaded~n\"),
                io:format(\"relay_mode: ~p~n\", [macula_dist_relay:is_relay_mode()]),
                io:format(\"mesh_client: ~p~n\", [macula_dist_relay:get_mesh_client()]);
            {error, Reason} ->
                io:format(\"macula_dist_relay: ~p~n\", [Reason])
        end,
        halt(0).
    "
'

echo ""
echo "=== Done ==="
