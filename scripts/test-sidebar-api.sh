#!/usr/bin/env bash
# Test sidebar config API endpoints via curl against a Unix socket.
# Usage: ./scripts/test-sidebar-api.sh [socket_path]
#
# If no socket path given, defaults to ~/.hecate/hecate-daemon/sockets/api.sock

set -euo pipefail

SOCKET="${1:-${HOME}/.hecate/hecate-daemon/sockets/api.sock}"
BASE="http://localhost"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC} $1"; }
fail() { echo -e "${RED}FAIL${NC} $1"; }
info() { echo -e "${YELLOW}INFO${NC} $1"; }

if [ ! -S "${SOCKET}" ]; then
    echo "Socket not found: ${SOCKET}"
    exit 1
fi

info "Testing against socket: ${SOCKET}"
echo ""

# --- Test 1: GET /api/config/sidebar (before any config exists) ---
info "Test 1: GET /api/config/sidebar (initial state)"
RESP=$(curl -s --unix-socket "${SOCKET}" "${BASE}/api/config/sidebar")
echo "  Response: ${RESP}"

if echo "${RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok']==True" 2>/dev/null; then
    pass "GET returns ok:true"
else
    fail "GET did not return ok:true"
fi
echo ""

# --- Test 2: PUT /api/config/sidebar ---
info "Test 2: PUT /api/config/sidebar (save groups)"
PUT_BODY='{"groups":[{"name":"SYSTEM","icon":"\u2699\uFE0F","collapsed":false,"apps":["settings","appstore"]},{"name":"DEVELOP","icon":"\uD83D\uDEE0\uFE0F","collapsed":false,"apps":["martha","macula"]},{"name":"ARCADE","icon":"\uD83C\uDFAE","collapsed":true,"apps":["snake-duel"]}]}'

RESP=$(curl -s -X PUT \
    -H "Content-Type: application/json" \
    -d "${PUT_BODY}" \
    --unix-socket "${SOCKET}" "${BASE}/api/config/sidebar")
echo "  Response: ${RESP}"

if echo "${RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['ok']==True" 2>/dev/null; then
    pass "PUT returns ok:true"
else
    fail "PUT did not return ok:true"
fi
echo ""

# --- Test 3: GET /api/config/sidebar (after PUT) ---
info "Test 3: GET /api/config/sidebar (round-trip verification)"
RESP=$(curl -s --unix-socket "${SOCKET}" "${BASE}/api/config/sidebar")
echo "  Response: ${RESP}"

GROUP_COUNT=$(echo "${RESP}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('groups',[])))" 2>/dev/null || echo "0")
if [ "${GROUP_COUNT}" = "3" ]; then
    pass "GET returns 3 groups after PUT"
else
    fail "Expected 3 groups, got ${GROUP_COUNT}"
fi
echo ""

# --- Test 4: Verify YAML file was written ---
info "Test 4: Check YAML file on disk"
YAML_PATH="${HOME}/.hecate/config/sidebar.yaml"
if [ -f "${YAML_PATH}" ]; then
    pass "sidebar.yaml exists at ${YAML_PATH}"
    echo "  Contents:"
    cat "${YAML_PATH}" | sed 's/^/    /'
else
    fail "sidebar.yaml not found at ${YAML_PATH}"
fi
echo ""

# --- Test 5: Method not allowed ---
info "Test 5: POST /api/config/sidebar (should be 405)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{}' \
    --unix-socket "${SOCKET}" "${BASE}/api/config/sidebar")
if [ "${HTTP_CODE}" = "405" ]; then
    pass "POST returns 405 Method Not Allowed"
else
    fail "POST returned ${HTTP_CODE}, expected 405"
fi
echo ""

# --- Test 6: Invalid PUT body ---
info "Test 6: PUT with invalid body"
RESP=$(curl -s -X PUT \
    -H "Content-Type: application/json" \
    -d 'not json' \
    --unix-socket "${SOCKET}" "${BASE}/api/config/sidebar")
echo "  Response: ${RESP}"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Content-Type: application/json" \
    -d 'not json' \
    --unix-socket "${SOCKET}" "${BASE}/api/config/sidebar")
if [ "${HTTP_CODE}" = "400" ]; then
    pass "Invalid body returns 400"
else
    fail "Invalid body returned ${HTTP_CODE}, expected 400"
fi
echo ""

info "All tests complete."
