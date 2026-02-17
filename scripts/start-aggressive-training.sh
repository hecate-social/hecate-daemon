#!/usr/bin/env bash
set -euo pipefail

# Start gladiator training with aggressive fitness weights (win-focused)
# Usage: ./scripts/start-aggressive-training.sh [pop_size] [max_gen] [opp_af]

SOCKET="${HECATE_SOCKET:-$HOME/.hecate/daemon.sock}"
POP_SIZE="${1:-100}"
MAX_GEN="${2:-100}"
OPP_AF="${3:-30}"

echo "Starting aggressive gladiator training..."
echo "  Population: ${POP_SIZE}"
echo "  Generations: ${MAX_GEN}"
echo "  Opponent AF: ${OPP_AF}"
echo "  Fitness: win-focused (win=500, kill=300, wall_kill=200, food=20)"

PAYLOAD=$(cat <<'ENDJSON'
{
  "population_size": POP_SIZE_PLACEHOLDER,
  "max_generations": MAX_GEN_PLACEHOLDER,
  "opponent_af": OPP_AF_PLACEHOLDER,
  "episodes_per_eval": 3,
  "champion_count": 3,
  "training_config": {
    "enable_ltc": true,
    "enable_lc_chain": true,
    "fitness_weights": {
      "survival_weight": 0.05,
      "food_weight": 20.0,
      "win_bonus": 500.0,
      "draw_bonus": 25.0,
      "kill_bonus": 300.0,
      "proximity_weight": 0.3,
      "circle_penalty": -1.0,
      "wall_kill_bonus": 200.0
    }
  }
}
ENDJSON
)

PAYLOAD="${PAYLOAD//POP_SIZE_PLACEHOLDER/${POP_SIZE}}"
PAYLOAD="${PAYLOAD//MAX_GEN_PLACEHOLDER/${MAX_GEN}}"
PAYLOAD="${PAYLOAD//OPP_AF_PLACEHOLDER/${OPP_AF}}"

RESPONSE=$(curl -s --unix-socket "${SOCKET}" \
  -X POST "http://localhost/api/arcade/gladiators/stables" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")

echo ""
echo "Response:"
echo "${RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${RESPONSE}"
