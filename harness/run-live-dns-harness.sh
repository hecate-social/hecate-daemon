#!/usr/bin/env bash
# Live, no-stubs verification harness for resolve_mesh_names + serve_dns_over_mesh.
#
# Connects a real macula V2 pool to the live relay/station fleet, publishes a
# fresh station_endpoint record into the DHT, and checks it resolves back through
# every layer: raw find_record -> Tier-1 resolve + trust verify -> serve_query
# (the DNS wire bridge) -> an external DNS client over the live UDP socket.
# Also verifies the cache-invalidation PMs bootstrap-subscribed to the pool.
#
# Runs in a bare `erl' node: NO Erlang distribution (no epmd / no cluster
# flood), NO -heart (no resurrection). Writes nothing to disk. The test
# record self-expires (5 min TTL) after the harness exits.
#
# Usage:
#   harness/run-live-dns-harness.sh [--relays URL,URL,...] [--port N] [--keep SECONDS]
#
#   --relays   comma-separated relay/station URLs (default: the be-* fleet)
#   --port     UDP port for the DNS listener (default: 5353)
#   --keep     after the report, keep the listener up this many seconds so you
#              can poke it by hand (default: 0 = exit immediately)
#
# Env vars HARNESS_RELAYS / HARNESS_DNS_PORT / HARNESS_KEEP_ALIVE_S work too.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
BUILD="$REPO/_build/default/lib"

RELAYS="${HARNESS_RELAYS:-https://station-be-brussels.macula.io:4433,https://station-be-antwerp.macula.io:4433,https://station-be-hasselt.macula.io:4433}"
DNS_PORT="${HARNESS_DNS_PORT:-5353}"
KEEP="${HARNESS_KEEP_ALIVE_S:-0}"

while [ $# -gt 0 ]; do
  case "$1" in
    --relays) RELAYS="$2"; shift 2;;
    --port)   DNS_PORT="$2"; shift 2;;
    --keep)   KEEP="$2"; shift 2;;
    -h|--help) sed -n '2,21p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

# --- ensure the umbrella is built ---
if [ ! -d "$BUILD/macula/ebin" ] || [ ! -d "$BUILD/resolve_mesh_names/ebin" ] || [ ! -d "$BUILD/serve_dns_over_mesh/ebin" ]; then
  echo "==> building (rebar3 compile) ..."
  ( cd "$REPO" && rebar3 compile >/dev/null )
fi

# --- compile the harness module against the build ---
mkdir -p "$HERE/ebin"
echo "==> compiling live_dns_harness.erl ..."
INCS=()
[ -d "$BUILD/macula/include" ] && INCS+=( -I "$BUILD/macula/include" )
erlc -o "$HERE/ebin" "${INCS[@]}" \
  -pa "$BUILD/macula/ebin" -pa "$BUILD/resolve_mesh_names/ebin" -pa "$BUILD/serve_dns_over_mesh/ebin" \
  "$HERE/src/live_dns_harness.erl"

# --- code path: every umbrella + dep ebin, plus the harness ebin ---
PA=()
for d in "$BUILD"/*/ebin; do [ -d "$d" ] && PA+=( -pa "$d" ); done
PA+=( -pa "$HERE/ebin" )

# --- run in a throwaway cwd; no distribution; no -heart ---
WORK="$(mktemp -d "${TMPDIR:-/tmp}/hcv-harness.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT
cd "$WORK"

echo "==> running harness (relays=$RELAYS  dns_port=$DNS_PORT  keep=$KEEP)"
echo
HARNESS_RELAYS="$RELAYS" HARNESS_DNS_PORT="$DNS_PORT" HARNESS_KEEP_ALIVE_S="$KEEP" \
  erl -noshell "${PA[@]}" -eval 'live_dns_harness:main()'
