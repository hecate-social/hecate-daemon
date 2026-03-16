#!/usr/bin/env bash
set -euo pipefail

# End-to-end SSE emitter test:
# 1. Connect to /api/events SSE endpoint
# 2. POST a test event via /api/events/test
# 3. Verify the event arrives on the SSE stream

SOCKET="${HECATE_SOCKET_PATH:-${HOME}/.hecate-dev/hecate-daemon/sockets/api.sock}"
SSE_LOG=$(mktemp /tmp/sse-test-XXXXXX.log)
PASS=0
FAIL=0

log_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
log_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== SSE Emitter End-to-End Test ==="
echo "Socket: ${SOCKET}"
echo ""

# --- Step 1: Verify daemon is running ---
echo "1. Check daemon health..."
if curl -sf --unix-socket "${SOCKET}" http://localhost/health >/dev/null 2>&1; then
    log_pass "Daemon is running"
else
    log_fail "Daemon not reachable on ${SOCKET}"
    echo ""
    echo "Start the daemon first: ./scripts/dev-all.sh"
    exit 1
fi

# --- Step 2: Connect to SSE endpoint in background ---
echo ""
echo "2. Connect to SSE endpoint..."
curl -sf --unix-socket "${SOCKET}" http://localhost/api/events \
    --no-buffer -o "${SSE_LOG}" &
SSE_PID=$!
sleep 1

if kill -0 "${SSE_PID}" 2>/dev/null; then
    log_pass "SSE connection established (pid=${SSE_PID})"
else
    log_fail "SSE connection died immediately"
    cat "${SSE_LOG}" 2>/dev/null
    exit 1
fi

# --- Step 3: Check SSE connected ---
echo ""
echo "3. Check SSE handshake..."
if grep -q ": connected" "${SSE_LOG}"; then
    log_pass "Received SSE connected comment"
else
    log_fail "No connected message"
fi

# --- Step 4: Trigger a test broadcast ---
echo ""
echo "4. Trigger test broadcast via POST /api/events/test..."
BROADCAST_RESP=$(curl -sf --unix-socket "${SOCKET}" http://localhost/api/events/test \
    -X POST -H "Content-Type: application/json" \
    -d '{
        "event_type": "plugin_status_changed",
        "data": {
            "plugin_id": "test-org/test-plugin",
            "name": "test-plugin",
            "status": 4,
            "status_label": "Running",
            "available_actions": ["stop", "upgrade", "remove"]
        }
    }' 2>/dev/null || echo "FAIL")

if echo "${BROADCAST_RESP}" | grep -q '"ok"'; then
    log_pass "Test broadcast accepted by daemon"
else
    log_fail "Test broadcast failed: ${BROADCAST_RESP}"
fi

# --- Step 5: Wait for event to arrive on SSE ---
echo ""
echo "5. Wait for event on SSE stream..."
sleep 1

if grep -q "event: plugin_status_changed" "${SSE_LOG}"; then
    log_pass "Received plugin_status_changed event on SSE!"
    echo ""
    echo "--- Event payload ---"
    grep -A1 "event: plugin_status_changed" "${SSE_LOG}"
    echo "---"
else
    log_fail "No plugin_status_changed event on SSE stream"
    echo ""
    echo "--- SSE stream contents ---"
    cat "${SSE_LOG}"
    echo "---"
fi

# --- Step 6: Verify event data integrity ---
echo ""
echo "6. Verify event data..."
if grep -q '"test-plugin"' "${SSE_LOG}"; then
    log_pass "Event contains plugin name"
else
    log_fail "Event missing plugin name"
fi

if grep -q '"Running"' "${SSE_LOG}"; then
    log_pass "Event contains status_label"
else
    log_fail "Event missing status_label"
fi

# --- Cleanup ---
kill "${SSE_PID}" 2>/dev/null || true
rm -f "${SSE_LOG}"

# --- Summary ---
echo ""
echo "==================================="
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "==================================="

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
