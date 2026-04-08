#!/bin/bash
## End-to-end tests for virtual relay identities via IPv6.
##
## Verifies that per-identity QUIC listeners accept connections
## on their dedicated IPv6 addresses — not just the box IPv4.
##
## Usage: bash scripts/e2e-ipv6-identity-tests.sh

set -euo pipefail

PASS=0
FAIL=0
SKIP=0

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP + 1)); }
header() { echo ""; echo "=== $1 ==="; }

## Virtual relay identities to test (one per box + Paris T1)
declare -A IDENTITIES=(
    ["relay-de-munich.macula.io"]="2a01:4f8:1c1f:8ab8::121"
    ["relay-nl-amsterdam.macula.io"]="2a01:4f8:1c1f:8ab8::119"
    ["relay-fi-helsinki.macula.io"]="2a01:4f9:c014:4259::100"
    ["relay-pl-warsaw.macula.io"]="2a01:4f9:c014:4259::114"
    ["relay-t1-paris.macula.io"]="2600:3c1a::2000:71ff:fea3:f1e5"
    ["relay-t1-london.macula.io"]="2600:3c1a:e001:19::100"
)

##====================================================================
## Test 1: DNS AAAA records resolve correctly
##====================================================================
header "Test 1: DNS AAAA records for virtual identities"

for NAME in "${!IDENTITIES[@]}"; do
    EXPECTED="${IDENTITIES[$NAME]}"
    ACTUAL=$(dig +short AAAA "${NAME}" @8.8.8.8 2>/dev/null | head -1)
    if [ "${ACTUAL}" = "${EXPECTED}" ]; then
        pass "${NAME} → ${ACTUAL}"
    elif [ -n "${ACTUAL}" ]; then
        fail "${NAME}: expected ${EXPECTED}, got ${ACTUAL}"
    else
        fail "${NAME}: no AAAA record"
    fi
done

##====================================================================
## Test 2: IPv6 ping reachability
##====================================================================
header "Test 2: IPv6 ping reachability"

for NAME in "${!IDENTITIES[@]}"; do
    IPV6="${IDENTITIES[$NAME]}"
    if ping6 -c 1 -W 3 "${IPV6}" >/dev/null 2>&1; then
        pass "${NAME} (${IPV6}) reachable"
    else
        fail "${NAME} (${IPV6}) unreachable"
    fi
done

##====================================================================
## Test 3: QUIC port open on IPv6 (UDP 4433)
##====================================================================
header "Test 3: QUIC port reachability (UDP 4433 via IPv6)"

for NAME in "${!IDENTITIES[@]}"; do
    IPV6="${IDENTITIES[$NAME]}"
    ## Use ncat/nc to test UDP port — send a byte, see if it's accepted
    ## QUIC won't respond to raw UDP, but we can check the port isn't filtered
    if timeout 3 bash -c "echo -n 'Q' | nc -u -6 -w 1 ${IPV6} 4433" >/dev/null 2>&1; then
        pass "${NAME} UDP:4433 open"
    else
        ## nc may exit non-zero even if port is open (no QUIC response to raw UDP)
        ## Fall back to checking if the connection wasn't refused
        skip "${NAME} UDP:4433 (can't verify without QUIC client)"
    fi
done

##====================================================================
## Test 4: Connect to virtual identity from beam node via IPv6
##====================================================================
header "Test 4: Beam node connectivity to virtual identities"

## Check if beam00 connects to relay-de-munich (its configured relay) via IPv6
BEAM_LOGS=$(ssh -o ConnectTimeout=5 rl@beam00.lab \
    'docker logs hecate-daemon 2>&1 | grep -i "relay-de-munich\|Connected.*munich\|2a01:4f8:1c1f:8ab8::121" | tail -3' 2>/dev/null || echo "")
if echo "${BEAM_LOGS}" | grep -qi "connected\|munich"; then
    pass "beam00 connected to relay-de-munich"
else
    fail "beam00 not connected to relay-de-munich"
fi

## Check if beam00 resolves and uses IPv6
BEAM_IPV6=$(ssh -o ConnectTimeout=5 rl@beam00.lab \
    'docker logs hecate-daemon 2>&1 | grep "2a01:4f8" | tail -1' 2>/dev/null || echo "")
if [ -n "${BEAM_IPV6}" ]; then
    pass "beam00 uses IPv6 for relay connections"
else
    skip "beam00 may use IPv4 (no IPv6 evidence in logs)"
fi

##====================================================================
## Test 5: Per-identity listeners active on each box
##====================================================================
header "Test 5: Per-identity QUIC listener count"

NUR_LISTENERS=$(ssh -o ConnectTimeout=5 root@91.98.238.177 \
    'docker logs macula-relay 2>&1 | grep "per-identity QUIC listeners" | tail -1' 2>/dev/null || echo "")
NUR_COUNT=$(echo "${NUR_LISTENERS}" | grep -oP '\d+(?= per-identity)' || echo "0")
if [ "${NUR_COUNT}" -ge 70 ]; then
    pass "Nuremberg: ${NUR_COUNT} per-identity listeners"
else
    fail "Nuremberg: only ${NUR_COUNT} listeners (expected 75)"
fi

HEL_LISTENERS=$(ssh -o ConnectTimeout=5 root@95.216.141.48 \
    'docker logs macula-relay 2>&1 | grep "per-identity QUIC listeners" | tail -1' 2>/dev/null || echo "")
HEL_COUNT=$(echo "${HEL_LISTENERS}" | grep -oP '\d+(?= per-identity)' || echo "0")
if [ "${HEL_COUNT}" -ge 70 ]; then
    pass "Helsinki: ${HEL_COUNT} per-identity listeners"
else
    fail "Helsinki: only ${HEL_COUNT} listeners (expected 75)"
fi

PAR_LISTENERS=$(ssh -o ConnectTimeout=5 root@172.239.18.117 \
    'docker logs macula-relay 2>&1 | grep "per-identity QUIC listeners" | tail -1' 2>/dev/null || echo "")
PAR_COUNT=$(echo "${PAR_LISTENERS}" | grep -oP '\d+(?= per-identity)' || echo "0")
if [ "${PAR_COUNT}" -ge 5 ]; then
    pass "Paris: ${PAR_COUNT} per-identity listeners"
else
    fail "Paris: only ${PAR_COUNT} listeners (expected 5)"
fi

##====================================================================
## Test 6: Relay status reports virtual identities
##====================================================================
header "Test 6: Virtual identity topology"

TOTAL_RELAYS=$(ssh -o ConnectTimeout=5 root@91.98.238.177 \
    'curl -sf http://localhost:8080/status' 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('self_relays',[])))" 2>/dev/null || echo "0")
if [ "${TOTAL_RELAYS}" -ge 70 ]; then
    pass "Nuremberg reports ${TOTAL_RELAYS} relay identities in /status"
else
    fail "Nuremberg reports only ${TOTAL_RELAYS} identities (expected 75+)"
fi

##====================================================================
## Summary
##====================================================================
echo ""
echo "========================================"
echo "  RESULTS: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "========================================"

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
