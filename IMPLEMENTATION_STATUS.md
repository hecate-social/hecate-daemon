# Implementation Status - macula-hecate

**Last Updated:** 2026-02-01 (All 6 domains completed)

## Overview

macula-hecate implements a complete CQRS architecture with 6 bounded contexts following strict event sourcing principles.

## Completed Domains

### ✅ 1. Capabilities Domain
**Command Service:** `manage_capabilities`
- ✅ announce_capability slice (command + event + handler)
- ✅ ReckonDB integration via reckon_evoq
- ✅ Aggregate state management

**Query Service:** `query_capabilities`  
- ✅ Projections from capability events to SQLite
- ✅ Query handlers (discover, get, list)
- ✅ SQLite read models

### ✅ 2. Reputation Domain
**Command Service:** `manage_reputation`
- ✅ track_rpc_call slice (command + event + handler)
- ✅ flag_dispute slice (command + event + handler)
- ✅ resolve_dispute slice (command + event + handler)
- ✅ reputation_aggregate with scoring logic
- ✅ ReckonDB integration

**Query Service:** `query_reputation`
- ✅ rpc_call_tracked_v1_to_rpc_calls projection
- ✅ rpc_call_tracked_v1_to_reputation projection
- ✅ dispute_flagged_v1_to_disputes projection
- ✅ dispute_resolved_v1_to_disputes projection
- ✅ Query handlers (get_reputation, list_rpc_calls, list_disputes)
- ✅ SQLite tables (rpc_calls, agent_reputation, disputes)

### ✅ 3. Social Domain (100% Complete)
**Command Service:** `manage_social`
- ✅ follow_agent slice (command + event + handler + mesh publisher)
- ✅ unfollow_agent slice (command + event + handler + mesh publisher)
- ✅ endorse_capability slice (command + event + handler + mesh publisher)
- ✅ revoke_endorsement slice (command + event + handler + mesh publisher)
- ✅ social_aggregate with full event handling
- ✅ ReckonDB integration

**Query Service:** `query_social`
- ✅ Application infrastructure
- ✅ SQLite tables (followers, endorsements)
- ✅ agent_followed_v1_to_followers projection
- ✅ agent_unfollowed_v1_to_followers projection
- ✅ capability_endorsed_v1_to_endorsements projection
- ✅ endorsement_revoked_v1_to_endorsements projection
- ✅ get_followers query handler
- ✅ get_following query handler
- ✅ get_endorsements query handler
- ✅ Event subscriber routing all social events to projections

### ✅ 4. Subscriptions Domain (100% Complete)
**Command Service:** `manage_subscriptions`
- ✅ subscribe slice (command + event + handler + mesh publisher)
- ✅ unsubscribe slice (command + event + handler + mesh publisher)
- ✅ subscription_aggregate with full event handling
- ✅ ReckonDB integration

**Query Service:** `query_subscriptions`
- ✅ SQLite store with subscriptions table
- ✅ subscribed_v1_to_subscriptions projection
- ✅ unsubscribed_v1_to_subscriptions projection
- ✅ get_subscriptions query handler
- ✅ get_subscription_stats query handler
- ✅ Event subscriber routing all subscription events

### ✅ 5. Identities Domain (100% Complete)
**Command Service:** `manage_identities`
- ✅ register_identity slice (command + event + handler + mesh publisher)
- ✅ update_identity slice (command + event + handler + mesh publisher)
- ✅ identity_aggregate with full event handling
- ✅ ReckonDB integration

**Query Service:** `query_identities`
- ✅ SQLite store with identities table (with updated_at)
- ✅ identity_registered_v1_to_identities projection
- ✅ identity_updated_v1_to_identities projection
- ✅ find_identity query handler
- ✅ list_identities query handler
- ✅ Event subscriber routing all identity events

### ✅ 6. UCAN Domain (100% Complete)
**Command Service:** `manage_ucan`
- ✅ grant_capability slice (command + event + handler + mesh publisher)
- ✅ revoke_capability slice (command + event + handler + mesh publisher)
- ✅ ucan_aggregate with full event handling
- ✅ ReckonDB integration

**Query Service:** `query_ucan`
- ✅ SQLite store with capabilities table
- ✅ capability_granted_v1_to_capabilities projection
- ✅ capability_revoked_v1_to_capabilities projection
- ✅ find_capabilities query handler (by_issuer, by_audience)
- ✅ verify_capability query handler
- ✅ Event subscriber routing all UCAN events

## Architecture Summary

### Command Services (6)
All command services use embedded ReckonDB instances via reckon_evoq for event storage:

```erlang
{ok, _Store} = reckon_db:start_link(#{
    name => {domain}_store,
    data_dir => DataDir,
    mode => embedded
})
```

### Query Services (6)
All query services use SQLite for optimized read models:

```erlang
{ok, Conn} = esqlite3:open(DbPath),
application:set_env(query_{domain}, db_conn, Conn)
```

### Event Flow
```
HTTP API → Command Service → Handler → Event
    ↓
ReckonDB (local storage)
    ↓
Mesh DHT pub/sub
    ↓
Query Service → Projection → SQLite read model
```

## HTTP API Endpoints

All domain operations are exposed via Cowboy REST API on port 4444:

### Social Domain
| Method | Endpoint | Handler |
|--------|----------|---------|
| POST | `/social/follow` | Follow an agent |
| POST | `/social/unfollow` | Unfollow an agent |
| POST | `/social/endorse` | Endorse a capability |
| POST | `/social/endorsement/revoke` | Revoke an endorsement |
| GET | `/social/followers/:agent_identity` | Get followers |
| GET | `/social/following/:agent_identity` | Get following |
| GET | `/social/endorsements/:agent_identity` | Get endorsements |

### Subscriptions Domain
| Method | Endpoint | Handler |
|--------|----------|---------|
| GET | `/subscriptions` | List subscriptions |
| POST | `/subscriptions/subscribe` | Subscribe to topic |
| POST | `/subscriptions/unsubscribe` | Unsubscribe from topic |
| GET | `/subscriptions/stats` | Get subscription stats |

### Identities Domain
| Method | Endpoint | Handler |
|--------|----------|---------|
| GET | `/agents` | List identities |
| POST | `/agents/register` | Register identity |
| GET | `/agents/:agent_identity` | Get identity |
| POST | `/agents/:agent_identity/update` | Update identity |

### UCAN Domain
| Method | Endpoint | Handler |
|--------|----------|---------|
| POST | `/ucan/grant` | Grant capability |
| DELETE | `/ucan/revoke/:capability_id` | Revoke capability |
| GET | `/ucan/capabilities` | List capabilities |
| GET | `/ucan/verify/:capability_id` | Verify capability by ID |
| POST | `/ucan/verify` | Verify capability by action |

### Capabilities Domain
| Method | Endpoint | Handler |
|--------|----------|---------|
| POST | `/capabilities/announce` | Announce capability |
| GET | `/capabilities/discover` | Discover capabilities |
| GET | `/capabilities/:mri` | Get capability |

### Reputation Domain
| Method | Endpoint | Handler |
|--------|----------|---------|
| GET | `/reputation/:agent_identity` | Get reputation |
| GET | `/rpc-calls` | List RPC calls |
| GET | `/disputes` | List disputes |
| POST | `/rpc/track` | Track RPC call |

## Compilation Status

✅ All 15 apps compile successfully:
- 6 command services (`manage_*`)
- 6 query services (`query_*`)
- 2 infrastructure apps (`hecate`, `hecate_api`)
- 1 mesh integration (`hecate_mesh`)

```bash
$ rebar3 compile
===> Compiling manage_capabilities
===> Compiling query_capabilities
===> Compiling manage_reputation
===> Compiling query_reputation
===> Compiling manage_social
===> Compiling query_social
===> Compiling manage_subscriptions
===> Compiling query_subscriptions
===> Compiling manage_identities
===> Compiling query_identities
===> Compiling manage_ucan
===> Compiling query_ucan
===> Compiling hecate
```

## Next Steps

1. ✅ ~~Complete domain slices~~ - All 6 domains implemented
2. ✅ ~~Add projections~~ - All projection modules implemented
3. ✅ ~~Add query handlers~~ - All query handlers implemented
4. ✅ ~~Wire up HTTP API~~ - All domains integrated into `hecate_api` Cowboy routes
5. ⚠️ **Mesh integration needs redesign** - Current implementation is incorrect (see below)
6. **Add tests** - Unit and integration tests for all domains
7. **Documentation** - API reference and usage examples
8. **Gateway mode planning** - Design how hecate acts as gateway for external services

## ⚠️ Mesh Integration - Architectural Correction Required

**Current implementation is WRONG.** The `hecate_mesh_subscriber` violates the Cartwheel Architecture.

**See full documentation:** [docs/ARCHITECTURE.md#cartwheel-architecture](docs/ARCHITECTURE.md#cartwheel-architecture)

![Cartwheel Architecture](assets/cartwheel-architecture.svg)

### Current (Incorrect)
```
Domain EVENT → hecate_mesh_publisher → Mesh → hecate_mesh_subscriber → Projection
```
- Publishes domain EVENTS directly to mesh
- Central dispatcher routes to all projections
- Bypasses aggregates on receiving side

### Correct Architecture (Cartwheel)

**Key distinction: FACTS vs EVENTS**
- EVENTS = Internal domain events (stored in ReckonDB)
- FACTS = External integration messages (published to mesh)
- These are NOT the same thing

**Pub/Sub Pattern:**
```
AgentA: EVENT → EMITTER → FACT → Mesh Topic (past tense)
AgentB: Mesh → LISTENER → COMMAND → Aggregate → EVENT → Projection
```

**RPC Pattern:**
```
AgentA: REQUESTER → HOPE → DHT RPC Endpoint (present tense)
AgentB: RESPONDER → COMMAND → Aggregate → FEEDBACK → AgentA
```

### Components Needed

| Component | Purpose |
|-----------|---------|
| EMITTER | Converts domain EVENT → FACT for mesh publication |
| LISTENER | Receives FACT → creates COMMAND → dispatches to aggregate |
| REQUESTER | Sends HOPE to remote RPC endpoint, receives FEEDBACK |
| RESPONDER | Receives HOPE → COMMAND → aggregate → sends FEEDBACK |

### Naming Conventions

| Type | Tense | Example |
|------|-------|---------|
| HOPE | Present | `capability.announce`, `rpc.call` |
| FACT | Past | `capability.available`, `agent.joined` |
| FEEDBACK | Result | Response to HOPE |

### TODO: Gateway Mode Planning

Design required for hecate as gateway for external services:
- How do external services register their pub/sub topics?
- How do external services advertise RPC endpoints?
- Topic namespace isolation per service
- Authentication/authorization for service registration
- Routing rules for incoming FACTS/HOPES to correct service

## Dependencies

- **reckon_db**: 1.2.2 (Core event store)
- **reckon_evoq**: 1.1.2 (Evoq adapter for ReckonDB)
- **esqlite**: 0.8.8 (SQLite for read models)
- **json**: OTP built-in (JSON encoding, OTP 27+)

## Related Plans

- `plans/PLAN_CQRS_ARCHITECTURE.md` - Complete architecture specification
- `plans/PLAN_ANNOUNCE_CAPABILITY.md` - Capabilities domain implementation
- `plans/PLAN_TRACK_RPC_CALL.md` - Reputation domain implementation
