#!/usr/bin/env bash
set -euo pipefail

# Start a champion duel match
# Usage: ./scripts/start-champion-duel.sh <stable_id> [rank] [opponent_af] [tick_ms]

SOCKET="${HECATE_SOCKET:-$HOME/.hecate/daemon.sock}"
STABLE_ID="${1:?Usage: $0 <stable_id> [rank] [opponent_af] [tick_ms]}"
RANK="${2:-1}"
OPP_AF="${3:-30}"
TICK_MS="${4:-100}"

echo "Starting champion duel..."
echo "  Stable: ${STABLE_ID}"
echo "  Rank: ${RANK}"
echo "  Opponent AF: ${OPP_AF}"
echo "  Tick MS: ${TICK_MS}"

PAYLOAD=$(cat <<ENDJSON
{
  "rank": ${RANK},
  "opponent_af": ${OPP_AF},
  "tick_ms": ${TICK_MS}
}
ENDJSON
)

RESPONSE=$(curl -s --unix-socket "${SOCKET}" \
  -X POST "http://localhost/api/arcade/gladiators/stables/${STABLE_ID}/duel" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")

echo ""
echo "Response:"
echo "${RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${RESPONSE}"
