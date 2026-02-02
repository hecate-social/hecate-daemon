# PLAN: CQRS Architecture for macula-hecate

**Status:** ⚙️ In Progress (Core complete, end-to-end tests + documentation pending)
**Created:** 2026-01-31
**Last Updated:** 2026-02-02

---

## Overview

This document defines the **complete CQRS architecture** for macula-hecate, showing:

1. **Umbrella application structure** with separate apps per domain
2. **Command services (write side)** using ReckonDB for event sourcing
3. **Query services (read side)** using SQLite for read models
4. **All command/event/query slices** across all 6 domains
5. **Event flow** from commands through mesh to projections

**Key Principle:** Command and query responsibilities are **strictly separated**. Command services handle writes (commands → events → ReckonDB). Query services handle reads (events → projections → queries).

---

## Implementation Status Summary

| Component | Status | Notes |
|-----------|--------|-------|
| **Umbrella Structure** | ✅ Complete | 14 apps (6 cmd + 6 query + 2 infra) |
| **Command Services** | ✅ Complete | All 6 domains with slices |
| **Query Services** | ✅ Complete | All 6 domains with slices |
| **Mesh Listeners** | ✅ Complete | 7 listeners in domain supervisors |
| **Mesh Emitters** | ✅ Complete | 11 emitters in command slices |
| **ReckonDB Integration** | ✅ Configured | sys.config + hecate_app startup order |
| **API Endpoints** | ✅ Complete | All 6 domains wired to handlers |
| **Tests** | ✅ 90 passing | All tests pass |

---

## Actual Umbrella Application Structure

```
macula-hecate/
├── apps/
│   ├── hecate_api/                     # ✅ HTTP gateway (Cowboy)
│   ├── hecate_mesh/                    # ✅ Mesh connection
│   │
│   # ═══════════ COMMAND SERVICES ═══════════
│   ├── manage_capabilities/            # ✅ Complete
│   ├── manage_reputation/              # ✅ Complete
│   ├── manage_social/                  # ✅ Complete
│   ├── manage_subscriptions/           # ✅ Complete
│   ├── manage_identities/              # ✅ Complete
│   └── manage_ucan/                    # ✅ Complete
│   │
│   # ═══════════ QUERY SERVICES ═══════════
│   ├── query_capabilities/             # ✅ Complete
│   ├── query_reputation/               # ✅ Complete
│   ├── query_social/                   # ✅ Complete
│   ├── query_subscriptions/            # ✅ Complete
│   ├── query_identities/               # ✅ Complete
│   └── query_ucan/                     # ✅ Complete
│
├── src/                                # ✅ Core modules
│   ├── hecate_app.erl
│   ├── hecate_sup.erl
│   ├── hecate_identity.erl
│   ├── hecate_mesh.erl
│   ├── hecate_store.erl
│   ├── hecate_rpc.erl
│   ├── hecate_pubsub.erl
│   ├── hecate_ucan.erl
│   ├── hecate_cli.erl
│   └── hecate_api*.erl (router, about, pairing, pubsub)
│
├── config/sys.config                   # ✅ With managed_identities
├── test/                               # ✅ 90 tests passing
└── plans/                              # Documentation
```

---

## Complete Command/Event/Query Inventory (ACTUAL)

### Domain 1: Capabilities

**Command Service:** `manage_capabilities/`

| Slice | Command | Event | Handler | Emitter | Status |
|-------|---------|-------|---------|---------|--------|
| announce_capability | announce_capability_v1 | capability_announced_v1 | maybe_announce_capability | capability_announced_v1_to_mesh | ✅ |
| update_capability | update_capability_v1 | capability_updated_v1 | maybe_update_capability | capability_updated_v1_to_mesh | ✅ |
| retract_capability | retract_capability_v1 | capability_retracted_v1 | maybe_retract_capability | capability_retracted_v1_to_mesh | ✅ |

**Aggregate:** `capability_aggregate.erl` ✅

**Query Service:** `query_capabilities/`

| Component | File | Status |
|-----------|------|--------|
| Projection | capability_announced_v1_to_capabilities.erl | ✅ |
| Projection | capability_updated_v1_to_capabilities.erl | ✅ |
| Projection | capability_retracted_v1_to_capabilities.erl | ✅ |
| Query slice | find_capability/ | ✅ |
| Query slice | list_capabilities/ | ✅ |
| Listener | remote_capabilities_listener/ | ✅ |
| Store | query_capabilities_store.erl | ✅ |
| Subscriber | query_capabilities_subscriber.erl | ✅ |

---

### Domain 2: Reputation

**Command Service:** `manage_reputation/`

| Slice | Command | Event | Handler | Status |
|-------|---------|-------|---------|--------|
| track_rpc_call | track_rpc_call_v1 | rpc_call_tracked_v1 | maybe_track_rpc_call | ✅ |
| flag_dispute | flag_dispute_v1 | dispute_flagged_v1 | maybe_flag_dispute | ✅ |
| resolve_dispute | resolve_dispute_v1 | dispute_resolved_v1 | maybe_resolve_dispute | ✅ |
| record_dispute_against_me | record_dispute_against_me_v1 | dispute_against_me_recorded_v1 | maybe_record_dispute_against_me | ✅ |
| record_dispute_resolution | record_dispute_resolution_v1 | dispute_resolution_recorded_v1 | maybe_record_dispute_resolution | ✅ |
| **Listener** | dispute_events_listener/ | — | — | ✅ |

**Aggregate:** `reputation_aggregate.erl` ✅

**Query Service:** `query_reputation/`

| Component | File | Status |
|-----------|------|--------|
| Projection | rpc_call_tracked_v1_to_rpc_calls.erl | ✅ |
| Projection | rpc_call_tracked_v1_to_reputation.erl | ✅ |
| Projection | dispute_flagged_v1_to_disputes.erl | ✅ |
| Projection | dispute_resolved_v1_to_disputes.erl | ✅ |
| Query slice | get_reputation/ | ✅ |
| Query slice | list_rpc_calls/ | ✅ |
| Query slice | list_disputes/ | ✅ |

---

### Domain 3: Social

**Command Service:** `manage_social/`

| Slice | Command | Event | Handler | Emitter | Status |
|-------|---------|-------|---------|---------|--------|
| follow_agent | follow_agent_v1 | agent_followed_v1 | maybe_follow_agent | agent_followed_v1_to_mesh | ✅ |
| unfollow_agent | unfollow_agent_v1 | agent_unfollowed_v1 | maybe_unfollow_agent | agent_unfollowed_v1_to_mesh | ✅ |
| endorse_capability | endorse_capability_v1 | capability_endorsed_v1 | maybe_endorse_capability | capability_endorsed_v1_to_mesh | ✅ |
| revoke_endorsement | revoke_endorsement_v1 | endorsement_revoked_v1 | maybe_revoke_endorsement | endorsement_revoked_v1_to_mesh | ✅ |
| record_follower | record_follower_v1 | follower_recorded_v1 | maybe_record_follower | — | ✅ |
| record_unfollower | record_unfollower_v1 | unfollower_recorded_v1 | maybe_record_unfollower | — | ✅ |
| record_endorsement | record_endorsement_v1 | endorsement_received_v1 | maybe_record_endorsement | — | ✅ |
| record_endorsement_revoked | record_endorsement_revoked_v1 | endorsement_revocation_received_v1 | maybe_record_endorsement_revoked | — | ✅ |
| **Listener** | follower_events_listener/ | — | — | — | ✅ |
| **Listener** | endorsement_events_listener/ | — | — | — | ✅ |

**Aggregate:** `social_aggregate.erl` ✅

**Query Service:** `query_social/`

| Component | File | Status |
|-----------|------|--------|
| Projection | agent_followed_v1_to_followers.erl | ✅ |
| Projection | agent_unfollowed_v1_to_followers.erl | ✅ |
| Projection | capability_endorsed_v1_to_endorsements.erl | ✅ |
| Projection | endorsement_revoked_v1_to_endorsements.erl | ✅ |
| Query slice | get_followers/ | ✅ |
| Query slice | get_following/ | ✅ |
| Query slice | get_endorsements/ | ✅ |
| Query slice | get_social_graph/ | ✅ |
| Store | query_social_store.erl | ✅ |

---

### Domain 4: Subscriptions

**Command Service:** `manage_subscriptions/`

| Slice | Command | Event | Handler | Emitter | Status |
|-------|---------|-------|---------|---------|--------|
| subscribe | subscribe_v1 | subscribed_v1 | maybe_subscribe | subscribed_v1_to_mesh | ✅ |
| unsubscribe | unsubscribe_v1 | unsubscribed_v1 | maybe_unsubscribe | unsubscribed_v1_to_mesh | ✅ |
| record_subscriber | record_subscriber_v1 | subscriber_recorded_v1 | maybe_record_subscriber | — | ✅ |
| record_unsubscriber | record_unsubscriber_v1 | unsubscriber_recorded_v1 | maybe_record_unsubscriber | — | ✅ |
| **Listener** | subscriber_events_listener/ | — | — | — | ✅ |

**Aggregate:** `subscription_aggregate.erl` ✅

**Query Service:** `query_subscriptions/`

| Component | File | Status |
|-----------|------|--------|
| Projection | subscribed_v1_to_subscriptions.erl | ✅ |
| Projection | unsubscribed_v1_to_subscriptions.erl | ✅ |
| Query slice | get_subscriptions/ | ✅ |
| Query slice | get_subscription_stats/ | ✅ |
| Store | query_subscriptions_store.erl | ✅ |

---

### Domain 5: Identities

**Command Service:** `manage_identities/`

| Slice | Command | Event | Handler | Emitter | Status |
|-------|---------|-------|---------|---------|--------|
| register_identity | register_identity_v1 | identity_registered_v1 | maybe_register_identity | identity_registered_v1_to_mesh | ✅ |
| update_identity | update_identity_v1 | identity_updated_v1 | maybe_update_identity | identity_updated_v1_to_mesh | ✅ |

**Aggregate:** `identity_aggregate.erl` ✅

**Query Service:** `query_identities/`

| Component | File | Status |
|-----------|------|--------|
| Projection | identity_registered_v1_to_identities.erl | ✅ |
| Projection | identity_updated_v1_to_identities.erl | ✅ |
| Query slice | find_identity/ | ✅ |
| Query slice | list_identities/ | ✅ |
| Listener | remote_identities_listener/ | ✅ |
| Store | query_identities_store.erl | ✅ |

---

### Domain 6: UCAN

**Command Service:** `manage_ucan/`

| Slice | Command | Event | Handler | Emitter | Status |
|-------|---------|-------|---------|---------|--------|
| grant_capability | grant_capability_v1 | capability_granted_v1 | maybe_grant_capability | capability_granted_v1_to_mesh | ✅ |
| revoke_capability | revoke_capability_v1 | capability_revoked_v1 | maybe_revoke_capability | capability_revoked_v1_to_mesh | ✅ |
| receive_capability | receive_capability_v1 | capability_received_v1 | maybe_receive_capability | — | ✅ |
| receive_capability_revocation | receive_capability_revocation_v1 | capability_revocation_received_v1 | maybe_receive_capability_revocation | — | ✅ |
| **Listener** | ucan_events_listener/ | — | — | — | ✅ |

**Aggregate:** `ucan_aggregate.erl` ✅

**Query Service:** `query_ucan/`

| Component | File | Status |
|-----------|------|--------|
| Projection | capability_granted_v1_to_capabilities.erl | ✅ |
| Projection | capability_revoked_v1_to_capabilities.erl | ✅ |
| Query slice | find_capabilities/ | ✅ |
| Query slice | verify_capability/ | ✅ |
| Store | query_ucan_store.erl | ✅ |

---

## Summary Statistics (Actual)

| Metric | Planned | Implemented | Status |
|--------|---------|-------------|--------|
| **Domains** | 6 | 6 | ✅ 100% |
| **Command Services** | 6 | 6 | ✅ 100% |
| **Query Services** | 6 | 6 | ✅ 100% |
| **Command Slices** | 18 | 27 | ✅ 150% (includes incoming fact handlers) |
| **Query Slices** | 17 | 18 | ✅ 106% |
| **Events** | 18 | 27+ | ✅ Exceeds plan |
| **Projections** | 18 | 18+ | ✅ 100% |
| **Mesh Listeners** | — | 7 | ✅ Added during refactor |
| **Mesh Emitters** | — | 11 | ✅ Added during refactor |
| **Total .erl Files** | ~108 | 188 | ✅ Well exceeds plan |

---

## Implementation Phases - UPDATED STATUS

### Phase 1: Core Infrastructure ✅ COMPLETE

- [x] Set up umbrella app structure
- [x] Create core modules (hecate_identity, hecate_mesh, hecate_store)
- [x] Create hecate_api gateway with Cowboy
- [x] Basic supervisor trees

### Phase 2: Capabilities Domain ✅ COMPLETE

- [x] Implement manage_capabilities command service
- [x] Implement query_capabilities query service
- [x] announce_capability slice complete
- [x] update_capability slice complete
- [x] retract_capability slice complete

### Phase 3: Reputation Domain ✅ COMPLETE

- [x] Implement manage_reputation command service
- [x] Implement query_reputation query service
- [x] track_rpc_call slice
- [x] flag_dispute slice
- [x] resolve_dispute slice
- [x] record_dispute_against_me slice (incoming fact)
- [x] record_dispute_resolution slice (incoming fact)
- [x] dispute_events_listener

### Phase 4: Social Domain ✅ COMPLETE

- [x] Implement manage_social command service
- [x] Implement query_social query service
- [x] follow/unfollow slices
- [x] endorse/revoke_endorsement slices
- [x] record_* slices (incoming facts)
- [x] follower_events_listener
- [x] endorsement_events_listener
- [x] get_social_graph query

### Phase 5: Supporting Domains ✅ COMPLETE

- [x] Implement manage_subscriptions + query_subscriptions
- [x] Implement manage_identities + query_identities
- [x] Implement manage_ucan + query_ucan
- [x] All listeners implemented

### Phase 6: Integration ⚙️ IN PROGRESS

- [x] Wire ReckonDB to all command services (each domain starts its own store)
- [x] Wire all domains to hecate_api (all routes configured, handlers wired)
- [ ] End-to-end testing
- [ ] Documentation
- [ ] Release

---

## Remaining Work

### High Priority (Complete MVP)

1. ~~**ReckonDB Integration**~~ ✅ DONE (2026-02-02)
   - Each domain supervisor calls `reckon_db_sup:start_store/1` in `init/1`
   - **VERTICAL SLICING**: Domains own their stores, NOT configured centrally
   - `hecate_app.erl` starts `reckon_db` app (infrastructure only)
   - Stores are NOT in sys.config - each domain defines its own config
   - Test event persistence (needs end-to-end test)

2. ~~**API Wiring**~~ ✅ DONE (2026-02-02)
   - All API handlers connected to command dispatchers
   - All API handlers connected to query handlers
   - Routes configured in `hecate_api_app.erl`

### Medium Priority (Feature Complete)

3. ~~**Missing Slices**~~ ✅ DONE (2026-02-02)
   - `manage_capabilities/update_capability/` ✅
   - `manage_capabilities/retract_capability/` ✅
   - `query_social/get_social_graph/` ✅

4. **End-to-End Tests** (NEXT)
   - Full flow tests: API → Command → Event → Projection → Query

### Low Priority (Polish)

5. **Documentation**
   - API documentation
   - Architecture guides

---

## Architecture Principles (Unchanged)

### 1. CQRS Separation

**Command Services (Write Side):**
- Accept commands from API or CLI
- Validate business rules
- Produce events
- Store events in ReckonDB (event store)
- Publish events to mesh DHT pub/sub

**Query Services (Read Side):**
- Subscribe to events from mesh DHT
- Project events into read models (SQLite)
- Handle read commands (queries)
- Return optimized read data

**Key Rule:** Command services NEVER query read models. Query services NEVER produce events.

### 2. Event Flow

```
REST API (POST /capabilities/announce)
    ↓
Command Service (manage_capabilities)
    ↓ validate command
Handler (maybe_announce_capability)
    ↓ create event
Event (capability_announced_v1)
    ↓ store
ReckonDB (local event store)
    ↓ publish (via emitter)
Macula Mesh DHT (topic: "capability.announced")
    ↓ subscribe (via listener)
Query Service (query_capabilities)
    ↓ project
Projection (capability_announced_v1_to_capabilities)
    ↓ write
SQLite Read Model (capabilities table)
    ↓ query
Read Command (find_capability)
    ↓ return
REST API (GET /capabilities/{id})
```

### 3. Mesh Integration (Corrected)

**Listeners** receive mesh FACTs and dispatch COMMANDs:
```
Mesh FACT → LISTENER → is_my_identity? → COMMAND → AGGREGATE → EVENT
```

**Emitters** publish domain EVENTs as mesh FACTs:
```
DOMAIN EVENT → EMITTER → MESH FACT
```

---

## Success Criteria

- [x] All command services have supervisor trees
- [x] All query services have supervisor trees
- [x] All events have projections
- [x] Mesh integration uses LISTENER/EMITTER pattern (not direct subscriber)
- [x] Hierarchical identity config (`managed_identities`)
- [x] All filtering uses `is_my_identity/1` check
- [x] 90 tests passing
- [ ] All command services use ReckonDB via reckon_evoq
- [ ] All query services use SQLite for read models (schema only)
- [ ] All events flow through Macula mesh DHT
- [ ] REST API exposes all capabilities

---

## References

- [PLAN_MESH_INTEGRATION_REFACTOR.md](PLAN_MESH_INTEGRATION_REFACTOR.md) — ✅ Complete
- [Cartwheel Overview](../guides/CARTWHEEL_OVERVIEW.md)
- [Projection Sequence Guide](../guides/CARTWHEEL_PROJECTION_SEQUENCE.md)
- [Write Sequence Guide](../guides/CARTWHEEL_WRITE_SEQUENCE.md)
- [Architecture Documentation](../docs/ARCHITECTURE.md)
