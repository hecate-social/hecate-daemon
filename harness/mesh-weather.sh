#!/usr/bin/env bash
# mesh-weather — what the Macula mesh looks like from THIS machine: the pool's
# identity, this box's geo, and the stations it seeds from with their city,
# IPv6, and round-trip latency. Read-only, no PASS/FAIL.
#
# Run it here, then on another box (scp it over, or via a connected daemon),
# and eyeball the two vantage points.
#
# Usage:
#   harness/mesh-weather.sh [--relays URL,URL,...]
#
# Env: HARNESS_RELAYS=url,url,...   (default: the be-* station fleet)
#      HECATE_GEO_CITY / HECATE_GEO_LAT / HECATE_GEO_LNG   (shows this box's geo)
set -euo pipefail
. "$(dirname "$0")/_common.sh"

while [ $# -gt 0 ]; do
  case "$1" in
    --relays) HARNESS_RELAYS="$2"; export HARNESS_RELAYS; shift 2;;
    -h|--help) sed -n '2,14p' "$0"; exit 0;;
    *) say "unknown arg: $1"; exit 2;;
  esac
done

harness_ensure_built
harness_compile harness_mesh.erl mesh_weather.erl
harness_run_erl 'mesh_weather:main()'
