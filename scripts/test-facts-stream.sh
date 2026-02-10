#!/usr/bin/env bash
# test-facts-stream.sh — E2E test for the TUI facts SSE stream
#
# Exercises the full pipeline:
#   POST /api/torch/initiate → pg event → _to_tui emitter → SSE stream
#
# Prerequisites: hecate daemon must be running on the unix socket.
#
# Usage:
#   bash scripts/test-facts-stream.sh

set -euo pipefail

SOCKET="/run/hecate/daemon.sock"
CURL="curl --silent --unix-socket ${SOCKET}"
BASE="http://localhost"
OUTPUT="/tmp/hecate-facts-test-$$"
TORCH_NAME="e2e-test-$(date +%s)"
PASS=0
FAIL=0
TORCH_ID=""

cleanup() {
    # Kill background curl if still running
    if [ -n "${SSE_PID:-}" ] && kill -0 "${SSE_PID}" 2>/dev/null; then
        kill "${SSE_PID}" 2>/dev/null || true
        wait "${SSE_PID}" 2>/dev/null || true
    fi
    rm -f "${OUTPUT}"

    # Archive the test torch if we got an ID
    if [ -n "${TORCH_ID}" ]; then
        ${CURL} -X POST \
            -H "Content-Type: application/json" \
            -d "{\"archived_by\":\"e2e-test\",\"reason\":\"test cleanup\"}" \
            "${BASE}/api/torches/${TORCH_ID}/archive" > /dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

assert_ok() {
    local desc="$1"
    local result="$2"
    if [ "${result}" = "ok" ]; then
        echo "  PASS: ${desc}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${desc}"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Facts Stream E2E Test ==="
echo ""

# Step 1: Check daemon health
echo "[1/5] Checking daemon health..."
HEALTH=$(${CURL} "${BASE}/health" 2>&1) || true
if echo "${HEALTH}" | grep -q '"healthy"'; then
    assert_ok "Daemon is healthy" "ok"
else
    echo "  FAIL: Daemon not reachable at ${SOCKET}"
    echo "  Response: ${HEALTH}"
    echo ""
    echo "RESULT: FAIL (daemon not running)"
    exit 1
fi

# Step 2: Start SSE listener in background
echo "[2/5] Starting SSE listener..."
${CURL} --no-buffer "${BASE}/api/facts/stream" > "${OUTPUT}" 2>&1 &
SSE_PID=$!
sleep 2

# Verify SSE process is still running
if ! kill -0 "${SSE_PID}" 2>/dev/null; then
    echo "  FAIL: SSE listener exited prematurely"
    echo ""
    echo "RESULT: FAIL"
    exit 1
fi
assert_ok "SSE listener connected" "ok"

# Step 3: Initiate a torch
echo "[3/5] Initiating test torch '${TORCH_NAME}'..."
INITIATE_RESP=$(${CURL} -X POST \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${TORCH_NAME}\",\"brief\":\"E2E test torch\",\"initiated_by\":\"e2e-test\"}" \
    "${BASE}/api/torch/initiate" 2>&1)

if echo "${INITIATE_RESP}" | grep -q '"ok":true'; then
    assert_ok "Torch initiated" "ok"
    # Extract torch_id for cleanup
    TORCH_ID=$(echo "${INITIATE_RESP}" | grep -o '"torch_id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "  Torch ID: ${TORCH_ID}"
else
    echo "  FAIL: Could not initiate torch"
    echo "  Response: ${INITIATE_RESP}"
    assert_ok "Torch initiated" "fail"
fi

# Step 4: Wait for fact delivery
echo "[4/5] Waiting for fact delivery..."
sleep 2

# Kill the SSE listener to flush output
kill "${SSE_PID}" 2>/dev/null || true
wait "${SSE_PID}" 2>/dev/null || true
SSE_PID=""

# Step 5: Verify SSE output
echo "[5/5] Verifying SSE output..."

if [ ! -f "${OUTPUT}" ]; then
    echo "  FAIL: Output file not found"
    assert_ok "Output file exists" "fail"
else
    SSE_CONTENT=$(cat "${OUTPUT}")

    # Check for data: line
    if echo "${SSE_CONTENT}" | grep -q "^data:"; then
        assert_ok "Contains SSE data line" "ok"
    else
        assert_ok "Contains SSE data line" "fail"
        echo "  Output was: ${SSE_CONTENT}"
    fi

    # Check for fact_type
    if echo "${SSE_CONTENT}" | grep -q '"fact_type":"torch_initiated_v1"'; then
        assert_ok "Contains fact_type torch_initiated_v1" "ok"
    elif echo "${SSE_CONTENT}" | grep -q '"fact_type"'; then
        assert_ok "Contains fact_type torch_initiated_v1" "fail"
        echo "  Found fact_type but wrong value"
    else
        assert_ok "Contains fact_type torch_initiated_v1" "fail"
    fi

    # Check for torch name in data
    if echo "${SSE_CONTENT}" | grep -q "\"name\":\"${TORCH_NAME}\""; then
        assert_ok "Contains torch name in data" "ok"
    else
        assert_ok "Contains torch name in data" "fail"
    fi
fi

# Summary
echo ""
echo "=== Results ==="
echo "  Passed: ${PASS}"
echo "  Failed: ${FAIL}"
echo ""

if [ "${FAIL}" -gt 0 ]; then
    echo "RESULT: FAIL"
    exit 1
else
    echo "RESULT: PASS"
    exit 0
fi
