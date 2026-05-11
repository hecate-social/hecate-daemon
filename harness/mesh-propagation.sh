#!/usr/bin/env bash
# mesh-propagation — measure a record crossing the mesh from one machine to
# another. Run --publish here, copy the printed --resolve command, run it on
# the other box.
#
# Usage:
#   harness/mesh-propagation.sh --publish [--keep SECONDS]
#   harness/mesh-propagation.sh --resolve <z32> [--key <hex>] [--pub-geo LAT,LNG]
#
# --publish puts a fresh self-expiring station_endpoint record into the live DHT
#   and prints the z32 + storage key + the exact --resolve command to run
#   elsewhere. --keep N: re-put it every 60 s and stay up N s (extends the
#   ~5-min TTL window). Default: publish once, exit.
# --resolve <z32>: derive the storage key from the z32, poll find_record until
#   it lands, report time-to-resolve / retries / signature-verified / advertised
#   v6 / (with --pub-geo + HECATE_GEO_* here) the great-circle distance.
#
# Env: HARNESS_RELAYS / HECATE_GEO_LAT / HECATE_GEO_LNG  (as for the other scripts)
set -euo pipefail
. "$(dirname "$0")/_common.sh"

ROLE='' Z32='' KEY='' PUBGEO='' KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) ROLE=publish; shift;;
    --resolve) ROLE=resolve; shift; case "${1:-}" in ''|-*) :;; *) Z32="$1"; shift;; esac;;
    --key)     shift; KEY="${1:?--key needs a value}"; shift;;
    --pub-geo) shift; PUBGEO="${1:?--pub-geo needs LAT,LNG}"; shift;;
    --keep)    shift; KEEP="${1:?--keep needs a number of seconds}"; shift;;
    -h|--help) sed -n '2,21p' "$0"; exit 0;;
    *) say "unknown arg: $1"; exit 2;;
  esac
done

[ -z "$ROLE" ] && { say "${c_red}need --publish or --resolve <z32>${c_reset}"; sed -n '2,21p' "$0"; exit 2; }
if [ "$ROLE" = resolve ] && [ -z "$Z32" ] && [ -z "$KEY" ]; then
  say "${c_red}--resolve needs a <z32> (or --key <hex>)${c_reset}"; exit 2
fi

harness_ensure_built
harness_compile harness_mesh.erl mesh_propagation.erl
HARNESS_MP_ROLE="$ROLE" HARNESS_MP_Z32="$Z32" HARNESS_MP_KEY="$KEY" \
  HARNESS_MP_PUBGEO="$PUBGEO" HARNESS_MP_KEEP="$KEEP" \
  harness_run_erl 'mesh_propagation:main()'
