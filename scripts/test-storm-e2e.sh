#!/usr/bin/env bash
# End-to-end test for Big Picture Event Storming lifecycle
set -euo pipefail

SOCK="${HOME}/.hecate/daemon.sock"
API="http://localhost"

c() { curl -s --unix-socket "$SOCK" "$@"; }
post() { c -X POST -H "Content-Type: application/json" "$@"; }

echo "=== Step 1: Initiate venture ==="
RESULT=$(post -d '{"name":"E2E Storm","brief":"Full lifecycle test","initiated_by":"test"}' "$API/api/ventures/initiate")
VID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['venture_id'])")
echo "Venture: $VID"

echo "=== Step 2: Submit vision ==="
post -d '{"vision":"Testing all storm phases"}' "$API/api/ventures/$VID/vision/submit" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('ok') or 'events' in d else d)"

echo "=== Step 3: Start discovery ==="
post "$API/api/ventures/$VID/discovery/start" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK -', d.get('events',[{}])[0].get('event_type','?'))"

echo "=== Step 4: Start storm ==="
post "$API/api/ventures/$VID/storm/start" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK -', d.get('events',[{}])[0].get('event_type','?'))"

echo "=== Step 5: Post stickies ==="
S1=$(post -d '{"text":"customer_registered","author":"test"}' "$API/api/ventures/$VID/storm/sticky" | python3 -c "import sys,json; print(json.load(sys.stdin)['sticky_id'])")
echo "Sticky 1: $S1"
S2=$(post -d '{"text":"order_placed","author":"test"}' "$API/api/ventures/$VID/storm/sticky" | python3 -c "import sys,json; print(json.load(sys.stdin)['sticky_id'])")
echo "Sticky 2: $S2"
S3=$(post -d '{"text":"payment_processed","author":"test"}' "$API/api/ventures/$VID/storm/sticky" | python3 -c "import sys,json; print(json.load(sys.stdin)['sticky_id'])")
echo "Sticky 3: $S3"

echo "=== Step 6: Stack S1 onto S2 ==="
STACK_RESULT=$(post -d "{\"target_sticky_id\":\"$S2\"}" "$API/api/ventures/$VID/storm/sticky/$S1/stack")
STACK_ID=$(echo "$STACK_RESULT" | python3 -c "import sys,json; evts=json.load(sys.stdin).get('events',[]); print(next((e['stack_id'] for e in evts if 'stack_id' in e),'none'))")
echo "Stack: $STACK_ID"

echo "=== Step 7: Advance to stack phase ==="
post -d '{"target_phase":"stack"}' "$API/api/ventures/$VID/storm/phase/advance" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Phase:', d.get('target_phase', d.get('error')))"

echo "=== Step 8: Advance to groom phase ==="
post -d '{"target_phase":"groom"}' "$API/api/ventures/$VID/storm/phase/advance" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Phase:', d.get('target_phase', d.get('error')))"

echo "=== Step 9: Groom the stack ==="
post -d "{\"canonical_sticky_id\":\"$S1\"}" "$API/api/ventures/$VID/storm/stack/$STACK_ID/groom" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Groomed:', d.get('events',[{}])[0].get('event_type','?'))"

echo "=== Step 10: Advance to cluster phase ==="
post -d '{"target_phase":"cluster"}' "$API/api/ventures/$VID/storm/phase/advance" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Phase:', d.get('target_phase', d.get('error')))"

echo "=== Step 11: Cluster S1 with S3 ==="
CL_RESULT=$(post -d "{\"target_cluster_id\":\"$S3\"}" "$API/api/ventures/$VID/storm/sticky/$S1/cluster")
CL_ID=$(echo "$CL_RESULT" | python3 -c "import sys,json; evts=json.load(sys.stdin).get('events',[]); print(next((e['cluster_id'] for e in evts if 'cluster_id' in e),'none'))")
echo "Cluster: $CL_ID"

echo "=== Step 12: Advance to name phase ==="
post -d '{"target_phase":"name"}' "$API/api/ventures/$VID/storm/phase/advance" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Phase:', d.get('target_phase', d.get('error')))"

echo "=== Step 13: Name the cluster ==="
post -d '{"name":"Customer Onboarding"}' "$API/api/ventures/$VID/storm/cluster/$CL_ID/name" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Named:', d.get('name', d.get('error')))"

echo "=== Step 14: Advance to map phase ==="
post -d '{"target_phase":"map"}' "$API/api/ventures/$VID/storm/phase/advance" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Phase:', d.get('target_phase', d.get('error')))"

echo "=== Step 15: Draw fact arrow ==="
post -d "{\"from_cluster\":\"$CL_ID\",\"to_cluster\":\"$CL_ID\",\"fact_name\":\"customer_onboarded\"}" "$API/api/ventures/$VID/storm/fact" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Arrow:', d.get('arrow_id', d.get('error')))"

echo "=== Step 16: Promote cluster to division ==="
post -d '{"division_name":"Customer Onboarding"}' "$API/api/ventures/$VID/storm/cluster/$CL_ID/promote" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Division:', d.get('division_id', d.get('error')))"

echo "=== Step 17: Advance to promoted phase ==="
post -d '{"target_phase":"promoted"}' "$API/api/ventures/$VID/storm/phase/advance" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Phase:', d.get('target_phase', d.get('error')))"

echo ""
echo "=== Verify: Storm state ==="
sleep 2  # Let projections catch up
c "$API/api/ventures/$VID/storm/state" | python3 -c "
import sys, json
d = json.load(sys.stdin)
s = d.get('storm', d)
print(f\"Phase: {s.get('phase')}\")
print(f\"Stickies: {len(s.get('stickies', []))}\")
print(f\"Clusters: {len(s.get('clusters', []))}\")
print(f\"Arrows: {len(s.get('arrows', []))}\")
for c in s.get('clusters', []):
    print(f\"  - {c.get('name')} ({c.get('status')})\")
for a in s.get('arrows', []):
    print(f\"  -> {a.get('fact_name')}\")
"

echo ""
echo "=== Verify: Raw events ==="
c "$API/api/ventures/$VID/events?limit=50" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f\"Total events: {d.get('count', len(d.get('events', [])))}\")
for e in d.get('events', []):
    print(f\"  [{e.get('version')}] {e.get('event_type')}\")
"

echo ""
echo "=== STORM E2E TEST COMPLETE ==="
