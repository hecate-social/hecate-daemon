#!/usr/bin/env bash
# mesh-bench — quantitative latency probes against the live mesh, with
# percentiles + a histogram. The bench_mesh engine in harness-script form (no
# daemon needed — its own transient macula pool). Read-only-ish: it writes a
# few transient RFC 3849 doc-prefix test records (~5-min TTL).
#
# Usage:
#   harness/mesh-bench.sh [-n ITERATIONS] [--probes p,p,...]
#
#   -n N            iterations per probe (default 30)
#   --probes LIST   comma-separated subset of: dht_find, dht_put, pubsub
#                   (default: all three)
#
# Env: HARNESS_RELAYS=url,url,...   (default: the be-* station fleet)
set -euo pipefail
. "$(dirname "$0")/_common.sh"

N=30 PROBES=''
while [ $# -gt 0 ]; do
  case "$1" in
    -n)        shift; N="${1:?-n needs a number}"; shift;;
    --probes)  shift; PROBES="${1:?--probes needs a comma list}"; shift;;
    -h|--help) sed -n '2,16p' "$0"; exit 0;;
    *) say "unknown arg: $1"; exit 2;;
  esac
done

harness_ensure_built
harness_compile harness_mesh.erl mesh_bench.erl
HARNESS_BENCH_N="$N" HARNESS_BENCH_PROBES="$PROBES" harness_run_erl 'mesh_bench:main()'
