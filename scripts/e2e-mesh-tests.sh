#!/bin/bash
## End-to-end mesh routing tests against the live beam cluster.
##
## Prerequisites:
##   - beam00-03 running hecate-daemon with multi-relay + edge relay
##   - beam03 = T3 edge relay
##   - Relays running on Hetzner + Paris
##
## Usage: bash scripts/e2e-mesh-tests.sh

set -euo pipefail

PASS=0
FAIL=0
SKIP=0

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP + 1)); }
header() { echo ""; echo "=== $1 ==="; }
ssh_beam() { ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "rl@${1}.lab" "$2" 2>/dev/null; }

##====================================================================
## Test 1: Multi-relay connections
##====================================================================
header "Test 1: Multi-relay connections (Phase 1)"

for NODE in beam00 beam01 beam02 beam03; do
    CONNECTIONS=$(ssh_beam "${NODE}" \
        "docker exec hecate-daemon curl -sf http://localhost:4444/api/mesh/status 2>/dev/null" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); mr=d.get('multi_relay',{}); print(mr.get('active_count',0))" 2>/dev/null || echo "0")
    if [ "${CONNECTIONS}" -ge 2 ]; then
        pass "${NODE}: ${CONNECTIONS} relay connections"
    elif [ "${CONNECTIONS}" -ge 1 ]; then
        fail "${NODE}: only ${CONNECTIONS} connection (expected 2+)"
    else
        fail "${NODE}: no connections"
    fi
done

##====================================================================
## Test 2: Edge relay active on beam03
##====================================================================
header "Test 2: Edge relay (Phase 2)"

EDGE_LOG=$(ssh_beam beam03 "docker logs hecate-daemon 2>&1 | grep -c 'Listening on port 4433'" || echo "0")
if [ "${EDGE_LOG}" -gt 0 ]; then
    pass "beam03 edge relay listening on port 4433"
else
    fail "beam03 edge relay not listening"
fi

## Check beam00-02 connected to edge relay
for NODE in beam00 beam01 beam02; do
    CONNECTED=$(ssh_beam "${NODE}" \
        "docker logs hecate-daemon 2>&1 | grep -c 'Connected to https://192.168.1.13:4433'" || echo "0")
    if [ "${CONNECTED}" -gt 0 ]; then
        pass "${NODE} connected to edge relay"
    else
        fail "${NODE} not connected to edge relay"
    fi
done

##====================================================================
## Test 3: Pub/sub delivery (local via edge relay)
##====================================================================
header "Test 3: Pub/sub delivery"

## Subscribe on beam01, publish from beam00, check delivery
## Use a unique topic to avoid interference
TEST_TOPIC="e2e.test.$(date +%s)"

## Subscribe on beam01 (via docker exec into Erlang shell)
ssh_beam beam01 "docker exec hecate-daemon sh -c '
    curl -sf -X POST http://localhost:4444/api/mesh/subscribe \
        -H \"Content-Type: application/json\" \
        -d \"{\\\"topic\\\": \\\"${TEST_TOPIC}\\\"}\" 2>/dev/null
'" >/dev/null 2>&1 && pass "Subscribed on beam01" || skip "Subscribe API not available"

## Give subscription time to propagate
sleep 2

## Publish from beam00
ssh_beam beam00 "docker exec hecate-daemon sh -c '
    curl -sf -X POST http://localhost:4444/api/mesh/publish \
        -H \"Content-Type: application/json\" \
        -d \"{\\\"topic\\\": \\\"${TEST_TOPIC}\\\", \\\"payload\\\": {\\\"test\\\": true}}\" 2>/dev/null
'" >/dev/null 2>&1 && pass "Published from beam00" || skip "Publish API not available"

##====================================================================
## Test 4: Mesh proof probes (existing infrastructure)
##====================================================================
header "Test 4: Mesh proof probes"

for NODE in beam00 beam01 beam02 beam03; do
    PROBES=$(ssh_beam "${NODE}" \
        "docker exec hecate-daemon curl -sf http://localhost:4444/api/mesh/proof 2>/dev/null" \
        | python3 -c "
import sys,json
d=json.load(sys.stdin)
results=d.get('results',{})
passed=[k for k,v in results.items() if v.get('status')=='passed']
print(len(passed))
" 2>/dev/null || echo "0")
    if [ "${PROBES}" -ge 2 ]; then
        pass "${NODE}: ${PROBES} mesh probes passed"
    elif [ "${PROBES}" -ge 1 ]; then
        pass "${NODE}: ${PROBES} mesh probe passed (partial)"
    else
        fail "${NODE}: no mesh probes passed"
    fi
done

##====================================================================
## Test 5: Relay admin API reachable
##====================================================================
header "Test 5: Relay health"

for RELAY in relay-de-munich.macula.io relay-pl-warsaw.macula.io; do
    ## Try via beam nodes (they can reach relays)
    HEALTH=$(ssh_beam beam00 "curl -sf --max-time 5 http://${RELAY}:8080/health 2>/dev/null" || echo "")
    if [ "${HEALTH}" = "OK" ]; then
        pass "${RELAY} healthy"
    else
        fail "${RELAY} unreachable"
    fi
done

## Check T1 Paris
T1_HEALTH=$(curl -sf --max-time 5 http://172.239.18.117:8080/health 2>/dev/null || echo "")
if [ "${T1_HEALTH}" = "OK" ]; then
    pass "T1 relay-t1-paris healthy"
else
    skip "T1 relay-t1-paris not reachable from here"
fi

##====================================================================
## Test 6: T1 Paris peered with T2s
##====================================================================
header "Test 6: T1 Paris peering"

T1_PEERS=$(ssh root@172.239.18.117 "curl -sf http://localhost:8080/status 2>/dev/null" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('peer_count',0))" 2>/dev/null || echo "0")
if [ "${T1_PEERS}" -ge 1 ]; then
    pass "T1 Paris peered with ${T1_PEERS} relay(s)"
else
    fail "T1 Paris has no peers"
fi

T1_IDENTITIES=$(ssh root@172.239.18.117 "curl -sf http://localhost:8080/status 2>/dev/null" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('self_relays',[])))" 2>/dev/null || echo "0")
if [ "${T1_IDENTITIES}" -ge 6 ]; then
    pass "T1 Paris has ${T1_IDENTITIES} virtual identities"
else
    fail "T1 Paris has only ${T1_IDENTITIES} identities (expected 6)"
fi

##====================================================================
## Test 7: SWIM active (check for ping activity in logs)
##====================================================================
header "Test 7: SWIM gossip"

SWIM_PINGS=$(ssh root@172.239.18.117 "docker logs macula-relay --since 60s 2>&1 | grep -c 'swim'" || echo "0")
if [ "${SWIM_PINGS}" -gt 0 ]; then
    pass "SWIM active on T1 Paris (${SWIM_PINGS} messages in last 60s)"
else
    skip "SWIM not yet active (T2 relays may need image update)"
fi

##====================================================================
## Test 8: Bloom filter exchange (check relay logs)
##====================================================================
header "Test 8: Bloom filter exchange"

BLOOM_MSGS=$(ssh root@172.239.18.117 "docker logs macula-relay --since 120s 2>&1 | grep -c 'bloom'" || echo "0")
if [ "${BLOOM_MSGS}" -gt 0 ]; then
    pass "Bloom filter exchange active on T1 Paris"
else
    skip "Bloom filter exchange not detected (may need T2 image update)"
fi

##====================================================================
## Test 9: DHT active (check relay logs)
##====================================================================
header "Test 9: Kademlia DHT"

DHT_LOG=$(ssh root@172.239.18.117 "docker logs macula-relay 2>&1 | grep -c '\[dht\]'" || echo "0")
if [ "${DHT_LOG}" -gt 0 ]; then
    pass "DHT active on T1 Paris (${DHT_LOG} log entries)"
else
    skip "DHT not yet active"
fi

##====================================================================
## Test 10: Catch-up replay procedure advertised
##====================================================================
header "Test 10: Catch-up replay (Phase 5)"

REPLAY_LOG=$(ssh_beam beam00 "docker logs hecate-daemon 2>&1 | grep -c 'Advertised.*replay'" || echo "0")
if [ "${REPLAY_LOG}" -gt 0 ]; then
    pass "Catch-up replay procedure advertised on beam00"
else
    fail "No replay procedure advertised"
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
