#!/usr/bin/env bash
set -euo pipefail

# Run N duels and report win rate
# Usage: ./scripts/batch-duel.sh <stable_id> [count] [rank] [opponent_af] [tick_ms]

SOCKET="${HECATE_SOCKET:-$HOME/.hecate/daemon.sock}"
STABLE_ID="${1:?Usage: $0 <stable_id> [count] [rank] [opponent_af] [tick_ms]}"
COUNT="${2:-5}"
RANK="${3:-1}"
OPP_AF="${4:-30}"
TICK_MS="${5:-50}"

WINS=0
LOSSES=0
DRAWS=0

echo "Running ${COUNT} duels for ${STABLE_ID} (rank ${RANK}) vs AF ${OPP_AF}"
echo "---"

for i in $(seq 1 "${COUNT}"); do
    PAYLOAD="{\"rank\": ${RANK}, \"opponent_af\": ${OPP_AF}, \"tick_ms\": ${TICK_MS}}"

    RESPONSE=$(curl -s --unix-socket "${SOCKET}" \
        -X POST "http://localhost/api/arcade/gladiators/stables/${STABLE_ID}/duel" \
        -H "Content-Type: application/json" \
        -d "${PAYLOAD}")

    MATCH_ID=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('match_id',''))" 2>/dev/null)

    if [ -z "${MATCH_ID}" ]; then
        echo "  Duel ${i}: FAILED to start — ${RESPONSE}"
        continue
    fi

    # Wait for match to finish (max 60s at tick_ms speed)
    MAX_WAIT=60
    RESULT=""
    for _ in $(seq 1 "${MAX_WAIT}"); do
        sleep 0.5
        # Check logs for this match
        RESULT=$(grep -h "${MATCH_ID}.*finished" \
            /home/rl/work/github.com/hecate-social/hecate-daemon/_build/default/rel/hecate/log/erlang.log.* \
            2>/dev/null | tail -1 || true)
        if [ -n "${RESULT}" ]; then
            break
        fi
    done

    if [ -z "${RESULT}" ]; then
        echo "  Duel ${i}: TIMEOUT (${MATCH_ID})"
        continue
    fi

    if echo "${RESULT}" | grep -q "winner=player1"; then
        WINS=$((WINS + 1))
        echo "  Duel ${i}: WIN  (${MATCH_ID})"
    elif echo "${RESULT}" | grep -q "winner=player2"; then
        LOSSES=$((LOSSES + 1))
        echo "  Duel ${i}: LOSS (${MATCH_ID})"
    else
        DRAWS=$((DRAWS + 1))
        echo "  Duel ${i}: DRAW (${MATCH_ID})"
    fi
done

TOTAL=$((WINS + LOSSES + DRAWS))
if [ "${TOTAL}" -gt 0 ]; then
    WIN_PCT=$(python3 -c "print(f'{${WINS}/${TOTAL}*100:.0f}%')")
else
    WIN_PCT="N/A"
fi

echo ""
echo "=== Results ==="
echo "  Wins:   ${WINS}"
echo "  Losses: ${LOSSES}"
echo "  Draws:  ${DRAWS}"
echo "  Win rate: ${WIN_PCT}"
