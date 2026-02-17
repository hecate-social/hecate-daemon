#!/usr/bin/env bash
set -euo pipefail

SOCKET="${HECATE_SOCKET:-$HOME/.hecate/daemon.sock}"
POP_SIZE="${1:-50}"
MAX_GEN="${2:-30}"
OPP_AF="${3:-30}"
EPISODES="${4:-3}"

echo "Starting gladiator training..."
echo "  Population: ${POP_SIZE}"
echo "  Generations: ${MAX_GEN}"
echo "  Opponent AF: ${OPP_AF}"
echo "  Episodes/eval: ${EPISODES}"

RESPONSE=$(curl -s --unix-socket "${SOCKET}" \
  -X POST 'http://localhost/api/arcade/gladiators/stables' \
  -H 'Content-Type: application/json' \
  -d "{\"population_size\":${POP_SIZE},\"max_generations\":${MAX_GEN},\"opponent_af\":${OPP_AF},\"episodes_per_eval\":${EPISODES}}")

echo ""
echo "Response:"
echo "${RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${RESPONSE}"
