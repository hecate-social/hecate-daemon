#!/usr/bin/env bash
# Live, no-stubs verification harness for resolve_mesh_names + serve_dns_over_mesh.
#
# Connects a real macula V2 pool to the live relay fleet, publishes a fresh
# station_endpoint record into the DHT, and checks it resolves back through every
# layer: raw find_record -> Tier-1 resolve + trust verify -> serve_query (the DNS
# wire bridge) -> an external DNS client over the live UDP socket. Also verifies
# the cache-invalidation PMs bootstrap-subscribed to the pool. Prints a PASS/FAIL
# table; exits non-zero on FAIL.
#
# Runs in a bare `erl' node: no Erlang distribution (no epmd / no cluster flood),
# no -heart, no disk writes. The test record self-expires (~5 min TTL).
#
# Usage:
#   harness/run-live-dns-harness.sh [--relays URL,URL,...] [--port N] [--keep SECONDS]
#
#   --relays   relay/station URLs (default: the be-* fleet)
#   --port     UDP port for the DNS listener (default: 5353)
#   --keep     after the report, keep the listener up this long for manual poking
#   HARNESS_DEBUG=1   adds payload/VR dumps
set -euo pipefail
. "$(dirname "$0")/_common.sh"

DNS_PORT="${HARNESS_DNS_PORT:-5353}"
KEEP="${HARNESS_KEEP_ALIVE_S:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    --relays) shift; HARNESS_RELAYS="${1:?--relays needs URL,URL,...}"; export HARNESS_RELAYS; shift;;
    --port)   shift; DNS_PORT="${1:?--port needs a number}"; shift;;
    --keep)   shift; KEEP="${1:?--keep needs a number of seconds}"; shift;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) say "unknown arg: $1"; exit 2;;
  esac
done

harness_ensure_built
harness_compile harness_mesh.erl live_dns_harness.erl
HARNESS_DNS_PORT="$DNS_PORT" HARNESS_KEEP_ALIVE_S="$KEEP" \
  harness_run_erl 'live_dns_harness:main()'
