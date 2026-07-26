#!/usr/bin/env bash
# Cross-daemon mesh_subscribe / mesh_publish round-trip demo.
#
# Two real daemons exchange a fact through the macula substrate:
#
#   subscriber-host: POST /api/mesh/subscriptions {topic}
#   publisher-host:  POST /api/mesh/publish {topic, fact}
#   subscriber-host: GET  /api/mesh/inbox?topic=...
#
# If the subscriber sees the publisher's fact, the Phase 3 wiring
# (guide_mesh_subscriptions + guide_mesh_inbox + project_mesh_activity +
# query_mesh_activity) is structurally + functionally sound on real
# boxes.
#
# Requires:
#   * Both hosts have the new daemon code deployed (Phase-3 onwards).
#   * Both hosts have hecate-daemon listening on its UDS at
#     ~/.hecate/hecate-daemon/sockets/api.sock.
#   * Both hosts are joined to the same realm and have at least one
#     reachable station in common (for the substrate to route).
#   * `ssh` + `curl` + `jq` available locally.
#
# Usage:
#   scripts/cross-daemon-mesh-demo.sh <subscriber-host> <publisher-host> [topic]
#
# Example:
#   scripts/cross-daemon-mesh-demo.sh beam01.lab beam02.lab chat.demo
#
# Exit codes:
#   0 — fact propagated subscriber-side
#   1 — bad usage / missing args
#   2 — subscribe-side HTTP failed
#   3 — publish-side HTTP failed
#   4 — inbox-side HTTP failed
#   5 — fact did not propagate inside the wait window

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────

if [[ $# -lt 2 ]]; then
  cat >&2 <<USAGE
usage: $(basename "$0") <subscriber-host> <publisher-host> [topic]
example: $(basename "$0") beam01.lab beam02.lab chat.demo
USAGE
  exit 1
fi

SUBSCRIBER_HOST="$1"
PUBLISHER_HOST="$2"
TOPIC="${3:-chat.demo}"
SOCKET="${HECATE_DAEMON_SOCKET:-\$HOME/.hecate/hecate-daemon/sockets/api.sock}"
WAIT_S="${WAIT_S:-3}"
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=accept-new -o ConnectTimeout=10}"

PUB_TAG="cross-daemon-mesh-demo-$$"
FACT_JSON=$(printf '{"topic":"%s","fact":{"from":"%s","tag":"%s","greeting":"hello"}}' \
              "$TOPIC" "$PUBLISHER_HOST" "$PUB_TAG")
SUB_JSON=$(printf '{"topic":"%s"}' "$TOPIC")

# ── Helpers ───────────────────────────────────────────────────────

# shellcheck disable=SC2086  # SSH_OPTS deliberately word-split
ssh_curl_post() {
  local host="$1" path="$2" body="$3"
  ssh $SSH_OPTS "$host" \
    "curl -sf --unix-socket $SOCKET \
       -X POST -H 'content-type: application/json' \
       -d '$body' http://localhost$path"
}

# shellcheck disable=SC2086
ssh_curl_get() {
  local host="$1" path="$2"
  ssh $SSH_OPTS "$host" \
    "curl -sf --unix-socket $SOCKET http://localhost$path"
}

echo "[1/4] subscribe on $SUBSCRIBER_HOST to topic '$TOPIC'..."
if ! ssh_curl_post "$SUBSCRIBER_HOST" "/api/mesh/subscriptions" "$SUB_JSON" \
       | jq -r '.fact_id // empty' >/dev/null; then
  echo "    ✗ subscribe failed" >&2
  exit 2
fi
echo "    ✓ subscribed"

echo "[2/4] publish on $PUBLISHER_HOST..."
if ! ssh_curl_post "$PUBLISHER_HOST" "/api/mesh/publish" "$FACT_JSON" \
       | jq -r '.fact_id // empty' >/dev/null; then
  echo "    ✗ publish failed" >&2
  exit 3
fi
echo "    ✓ published (tag=$PUB_TAG)"

echo "[3/4] waiting ${WAIT_S}s for propagation..."
sleep "$WAIT_S"

echo "[4/4] query inbox on $SUBSCRIBER_HOST..."
RESP=$(ssh_curl_get "$SUBSCRIBER_HOST" "/api/mesh/inbox?topic=$(printf '%s' "$TOPIC" | jq -sRr @uri)") || {
  echo "    ✗ inbox query failed" >&2
  exit 4
}

MATCH=$(printf '%s' "$RESP" | jq -r --arg t "$PUB_TAG" \
  '.events[] | select(.payload.fact.tag == $t) | .fact_id' | head -n1)

if [[ -z "$MATCH" ]]; then
  echo "    ✗ fact tag '$PUB_TAG' NOT seen by $SUBSCRIBER_HOST inside ${WAIT_S}s." >&2
  echo "    raw inbox (most recent ${WAIT_S}s window):" >&2
  printf '%s\n' "$RESP" | jq '.events[-5:]' >&2
  exit 5
fi

echo "    ✓ fact landed in inbox: fact_id=$MATCH"
echo
echo "Phase 3 cross-daemon round-trip: PASS"
