#!/usr/bin/env bash
set -euo pipefail

# Start gladiator training with LTC neurons enabled
# Usage: ./scripts/start-ltc-training.sh [pop_size] [max_gen] [opp_af] [episodes] [champion_count]

SOCKET="${HECATE_SOCKET:-$HOME/.hecate/hecate-daemon/sockets/api.sock}"
POP_SIZE="${1:-30}"
MAX_GEN="${2:-10}"
OPP_AF="${3:-30}"
EPISODES="${4:-2}"
CHAMPION_COUNT="${5:-3}"

echo "Starting LTC gladiator training..."
echo "  Population: ${POP_SIZE}"
echo "  Generations: ${MAX_GEN}"
echo "  Opponent AF: ${OPP_AF}"
echo "  Episodes/eval: ${EPISODES}"
echo "  Champion count: ${CHAMPION_COUNT}"
echo "  LTC: enabled"

PAYLOAD=$(cat <<ENDJSON
{
  "population_size": ${POP_SIZE},
  "max_generations": ${MAX_GEN},
  "opponent_af": ${OPP_AF},
  "episodes_per_eval": ${EPISODES},
  "champion_count": ${CHAMPION_COUNT},
  "training_config": {
    "enable_ltc": true
  }
}
ENDJSON
)

RESPONSE=$(curl -s --unix-socket "${SOCKET}" \
  -X POST "http://localhost/api/arcade/gladiators/stables" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")

echo ""
echo "Response:"
echo "${RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${RESPONSE}"
