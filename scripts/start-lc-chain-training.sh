#!/usr/bin/env bash
set -euo pipefail

# Start gladiator training with LC chain (adaptive evolution) enabled
# Usage: ./scripts/start-lc-chain-training.sh [pop_size] [max_gen] [opp_af] [episodes] [champion_count]

SOCKET="${HECATE_SOCKET:-$HOME/.hecate/daemon.sock}"
POP_SIZE="${1:-50}"
MAX_GEN="${2:-30}"
OPP_AF="${3:-30}"
EPISODES="${4:-3}"
CHAMPION_COUNT="${5:-3}"

echo "Starting LC chain gladiator training..."
echo "  Population: ${POP_SIZE}"
echo "  Generations: ${MAX_GEN}"
echo "  Opponent AF: ${OPP_AF}"
echo "  Episodes/eval: ${EPISODES}"
echo "  Champion count: ${CHAMPION_COUNT}"
echo "  LTC: enabled"
echo "  LC Chain: enabled"

PAYLOAD=$(cat <<ENDJSON
{
  "population_size": ${POP_SIZE},
  "max_generations": ${MAX_GEN},
  "opponent_af": ${OPP_AF},
  "episodes_per_eval": ${EPISODES},
  "champion_count": ${CHAMPION_COUNT},
  "training_config": {
    "enable_ltc": true,
    "enable_lc_chain": true
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
