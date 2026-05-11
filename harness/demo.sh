#!/usr/bin/env bash
# demo — a narrated walk-through of the mesh-naming stack. Good for a screencast
# or showing someone what this does: connect to the live station fleet → mint a
# fresh station identity → publish its endpoint into the mesh DHT → resolve it
# back (Tier-1, with trust verification) → resolve it again over plain DNS
# (nslookup against the daemon's listener). Test record only (~5-min TTL).
#
# Usage:
#   harness/demo.sh [--fast] [--keep SECONDS]
#
#   --fast    skip the dramatic pauses
#   --keep N  leave the DNS listener up for N s at the end so the audience can
#             nslookup it themselves
#
# Env: HARNESS_RELAYS=url,url,...   (default: the be-* station fleet)
set -euo pipefail
. "$(dirname "$0")/_common.sh"

FAST=0 KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fast)  FAST=1; shift;;
    --keep)  shift; KEEP="${1:?--keep needs a number of seconds}"; shift;;
    -h|--help) sed -n '2,15p' "$0"; exit 0;;
    *) say "unknown arg: $1"; exit 2;;
  esac
done

harness_ensure_built
harness_compile harness_mesh.erl mesh_demo.erl
HARNESS_DEMO_FAST="$FAST" HARNESS_DEMO_KEEP="$KEEP" harness_run_erl 'mesh_demo:main()'
