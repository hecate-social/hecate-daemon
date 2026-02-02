# Plan: Mesh Integration Refactoring

**Status:** ✅ COMPLETE (All 6 Phases Done)
**Created:** 2026-02-02
**Last Updated:** 2026-02-02
**Source:** APPRENTICE_INSTRUCTIONS.md + analysis

---

## Overview

Refactor hecate's mesh integration to properly implement the Cartwheel Architecture patterns. The current `hecate_mesh_subscriber.erl` fundamentally violates CQRS principles by routing mesh FACTs directly to projections, bypassing the command/aggregate layer.

---

## Corrected Mental Model

### What Hecate IS

```
Hecate = Gateway + Social/Mesh Services Built-In
```

Hecate is NOT just a sidecar for one agent. It is a **gateway** that:

1. **Hosts multiple BEAM services** on the same node
2. **Provides shared domains** (social, reputation, capabilities, etc.) that services use directly
3. **Manages mesh connectivity** on behalf of all hosted services
4. **Will proxy for non-BEAM services** (future: HTTP API + NATS)

### The Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Single BEAM Node                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                 Hecate Domains (SHARED)                │  │
│  │  ├── manage_capabilities  ├── query_capabilities       │  │
│  │  ├── manage_social        ├── query_social             │  │
│  │  ├── manage_reputation    ├── query_reputation         │  │
│  │  ├── manage_identities    ├── query_identities         │  │
│  │  ├── manage_subscriptions ├── query_subscriptions      │  │
│  │  ├── manage_ucan          ├── query_ucan               │  │
│  └────────────────────────────────────────────────────────┘  │
│         ▲              ▲              ▲                      │
│         │ direct call  │ direct call  │ direct call          │
│  ┌──────┴─────┐ ┌──────┴─────┐ ┌──────┴─────┐               │
│  │  Service A │ │  Service B │ │  Service C │               │
│  │  (weather) │ │  (transl.) │ │  (data)    │               │
│  └────────────┘ └────────────┘ └────────────┘               │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │              hecate_mesh (SHARED)                      │  │
│  │         Single mesh connection for all                 │  │
│  └──────────────────────┬─────────────────────────────────┘  │
└─────────────────────────┼────────────────────────────────────┘
                          │
                          ▼
                    Macula Mesh (DHT)
```

### How Services Use Hecate

Services are OTP applications on the same node. They use Hecate domains **directly**:

```erlang
%% weather_service_app.erl
start(_StartType, _StartArgs) ->
    %% Announce capability using Hecate domain directly
    {ok, _} = manage_capabilities:announce(#{
        capability_mri => <<"mri:capability:io.macula/my-gateway/weather/forecast">>,
        agent_identity => <<"mri:agent:io.macula/my-gateway/weather">>,
        description => <<"Weather forecasting service">>,
        tags => [<<"weather">>, <<"forecast">>]
    }),

    weather_service_sup:start_link().
```

### Identity Model: Hierarchical

```
Gateway Identity:  mri:agent:io.macula/my-gateway

Service Identities (children):
├── mri:agent:io.macula/my-gateway/weather
├── mri:agent:io.macula/my-gateway/translation
└── mri:agent:io.macula/my-gateway/data-api
```

---

## Problem Statement

### Current State (Wrong)

```
Mesh FACT → hecate_mesh_subscriber → projection (bypasses everything!)
```

**Issues:**
1. Treats external FACTs as internal EVENTs
2. Bypasses aggregate validation and business rules
3. No domain events stored in ReckonDB
4. Conflates "my data" with "other agents' data"
5. No filtering — receives ALL facts, not just relevant ones
6. Central dispatcher pattern (god-module)

### Target State (Correct)

**For Discovery (read-only caching):**
```
Mesh FACT → Listener → translate → Direct Projection → remote_* tables
```

**For Domain Participation:**
```
Mesh FACT → Listener → filter (is_my_identity?) → COMMAND → Aggregate → EVENT → stored → projected
```

---

## Mesh Facts Analysis

### Category 1: Discovery/Caching (Direct Projection)

Facts about OTHER agents. Cache for queries. No domain participation.

| Fact | Treatment | Target Table |
|------|-----------|--------------|
| `capability.announced` | Direct Projection | `remote_capabilities` |
| `capability.revised` | Direct Projection | `remote_capabilities` |
| `identity.registered` | Direct Projection | `remote_identities` |
| `identity.updated` | Direct Projection | `remote_identities` |

**Note:** These go to SEPARATE tables from local data (remote_* prefix).

### Category 2: Bilateral Relationships (Filtered → CMD Flow)

Only relevant when THIS gateway/service is the target.

| Fact | Filter | Treatment | Target |
|------|--------|-----------|--------|
| `social.followed` | target ∈ MY_IDENTITIES | LISTENER → `record_follower_v1` | `my_followers` |
| `social.unfollowed` | target ∈ MY_IDENTITIES | LISTENER → `record_unfollower_v1` | `my_followers` |
| `social.endorsed` | owner ∈ MY_IDENTITIES | LISTENER → `record_endorsement_v1` | `my_endorsements` |
| `social.endorsement_revoked` | owner ∈ MY_IDENTITIES | LISTENER → `record_endorsement_revoked_v1` | `my_endorsements` |
| `subscription.subscribed` | owner ∈ MY_IDENTITIES | LISTENER → `record_subscriber_v1` | `my_subscribers` |
| `subscription.unsubscribed` | owner ∈ MY_IDENTITIES | LISTENER → `record_unsubscriber_v1` | `my_subscribers` |

### Category 3: Disputes (Filtered → CMD Flow)

| Fact | Filter | Treatment |
|------|--------|-----------|
| `dispute.flagged` | accused ∈ MY_IDENTITIES | LISTENER → `record_dispute_against_me_v1` |
| `dispute.resolved` | accused ∈ MY_IDENTITIES | LISTENER → `record_dispute_resolution_v1` |

### Category 4: Security-Critical (Filtered → CMD Flow)

| Fact | Filter | Treatment |
|------|--------|-----------|
| `ucan.granted` | audience ∈ MY_IDENTITIES | LISTENER → `receive_capability_v1` |
| `ucan.revoked` | affects my tokens | LISTENER → `capability_revocation_received_v1` |

### Category 5: REMOVE

| Fact | Reason |
|------|--------|
| `rpc.tracked` | Each agent tracks their own. Redundant. |

---

## Phases (Priority Order from APPRENTICE_INSTRUCTIONS.md)

### Phase 1: Fix Horizontal Violations (Quick Wins) ✅ COMPLETE

- [x] **1a.** Flatten `query_capabilities/src/` — move files from `projections/` and `queries/` to `src/`
  - Moved `capability_announced_v1_to_capabilities.erl` to `src/`
  - Moved `find_capability.erl` and `list_capabilities.erl` to `src/`
  - Deleted empty `projections/` and `queries/` directories
- [x] **1b.** Consolidate duplicate API files — keep only `apps/hecate_api/src/` versions
  - Updated `apps/hecate_api/src/hecate_api_health.erl` with real identity check
  - Updated `apps/hecate_api/src/hecate_api_identity.erl` with actual implementation
  - Merged `apps/hecate_api/src/hecate_api_rpc.erl` with actual RPC + CQRS tracking
  - Kept `apps/hecate_api/src/hecate_api_ucan.erl` (already CQRS-aligned)

**Deleted from root `src/`:**
- ~~`hecate_api_health.erl`~~ (deleted)
- ~~`hecate_api_identity.erl`~~ (deleted)
- ~~`hecate_api_rpc.erl`~~ (deleted)
- ~~`hecate_api_ucan.erl`~~ (deleted)

**Note:** Root `src/` still has `hecate_api.erl`, `hecate_api_about.erl`, `hecate_api_pairing.erl`, `hecate_api_pubsub.erl` — these are unique endpoints not duplicated in apps, may need consolidation in future.

---

### Phase 1c: Convert Query Modules to Vertical Slices ✅ COMPLETE

Per user directive: "I prefer a separate directory, even if we have a single file (for now)...this makes things concise and extension-proof"

Converted 11 query modules across 5 query services into slice directories:

| Service | Slices Created |
|---------|----------------|
| `query_capabilities` | `find_capability/`, `list_capabilities/` |
| `query_identities` | `find_identity/`, `list_identities/` |
| `query_social` | `get_followers/`, `get_following/`, `get_endorsements/` |
| `query_subscriptions` | `get_subscriptions/`, `get_subscription_stats/` |
| `query_ucan` | `find_capabilities/`, `verify_capability/` |

**Note:** `query_reputation` already had proper slice directories with multiple files per slice (command + handler pattern) — this was the intended pattern.

---

### Phase 2: Separate Read Models (Foundation) ✅ COMPLETE

Added 7 remote tables for mesh fact data (separate from local domain event data):

| Store | New Table | Purpose |
|-------|-----------|---------|
| `query_capabilities_store` | `remote_capabilities` | Capabilities from OTHER agents |
| `query_identities_store` | `remote_identities` | Identities from OTHER agents |
| `query_social_store` | `my_followers` | People who follow ME |
| `query_social_store` | `my_endorsements` | Endorsements OF my capabilities |
| `query_subscriptions_store` | `my_subscribers` | Subscribers TO my services |
| `query_ucan_store` | `received_capabilities` | UCAN tokens granted TO me |
| `query_reputation_app` | `disputes_against_me` | Disputes against my services |

All tables include:
- `discovered_at` timestamp (when fact was received from mesh)
- `last_seen_at` for discovery tables (remote_capabilities, remote_identities)
- Appropriate indexes for query performance

**Files Modified:**
- `apps/query_capabilities/src/query_capabilities_store.erl`
- `apps/query_identities/src/query_identities_store.erl`
- `apps/query_social/src/query_social_store.erl`
- `apps/query_subscriptions/src/query_subscriptions_store.erl`
- `apps/query_ucan/src/query_ucan_store.erl`
- `apps/query_reputation/src/query_reputation_app.erl`

---

### Phase 3: New Commands for Incoming FACTs ✅ COMPLETE

Created 10 new command slices for handling incoming mesh facts ("someone did X to me" patterns):

| Service | Slices Created | Purpose |
|---------|----------------|---------|
| `manage_social` | `record_follower/` | Someone followed me |
| `manage_social` | `record_unfollower/` | Someone unfollowed me |
| `manage_social` | `record_endorsement/` | Someone endorsed my capability |
| `manage_social` | `record_endorsement_revoked/` | Someone revoked their endorsement |
| `manage_subscriptions` | `record_subscriber/` | Someone subscribed to my service |
| `manage_subscriptions` | `record_unsubscriber/` | Someone unsubscribed from my service |
| `manage_reputation` | `record_dispute_against_me/` | Someone filed a dispute against me |
| `manage_reputation` | `record_dispute_resolution/` | A dispute against me was resolved |
| `manage_ucan` | `receive_capability/` | Someone granted me a capability (CRITICAL) |
| `manage_ucan` | `receive_capability_revocation/` | A capability I received was revoked (CRITICAL) |

Each slice contains:
- `{command}_v1.erl` - Command record
- `{event}_v1.erl` - Domain event record
- `maybe_{command}.erl` - Handler with `handle/1` and `dispatch/1`

**Total files created:** 30 (3 per slice × 10 slices)

---

### Phase 4: Replace Subscriber with Listeners ✅ COMPLETE

**Deleted:** `apps/hecate_mesh/src/hecate_mesh_subscriber.erl` (the wrong god module)

**⚠️ CORRECTION:** Initially created a horizontal `hecate_mesh_listeners_sup.erl` — this was **wrong**. Listeners belong to their **domain supervisors** (vertical slicing), not a central listeners supervisor (horizontal thinking).

**Corrected Architecture — Listeners in Domain Supervisors:**

| Domain Supervisor | Listener(s) Added |
|-------------------|-------------------|
| `query_capabilities_sup` | `remote_capabilities_listener.erl` |
| `query_identities_sup` | `remote_identities_listener.erl` |
| `manage_social_sup` | `follower_events_listener.erl`, `endorsement_events_listener.erl` |
| `manage_subscriptions_sup` | `subscriber_events_listener.erl` |
| `manage_reputation_sup` | `dispute_events_listener.erl` |
| `manage_ucan_sup` | `ucan_events_listener.erl` (SECURITY-CRITICAL) |

**Files Created (in domain src/ directories):**
- `apps/query_capabilities/src/remote_capabilities_listener.erl`
- `apps/query_identities/src/remote_identities_listener.erl`
- `apps/manage_social/src/follower_events_listener.erl`
- `apps/manage_social/src/endorsement_events_listener.erl`
- `apps/manage_subscriptions/src/subscriber_events_listener.erl`
- `apps/manage_reputation/src/dispute_events_listener.erl`
- `apps/manage_ucan/src/ucan_events_listener.erl`

**Listener Categories:**
1. **Discovery listeners** (2): Direct projection to remote_* tables, no filtering
2. **Filtered listeners** (5): Check `is_my_identity/1` → dispatch COMMAND → AGGREGATE → stored EVENT

---

### Phase 5: Ensure All Emitters Supervised ✅ COMPLETE

**⚠️ ORIGINAL PLAN CORRECTED:** The original plan suggested consolidating emitters into `hecate_mesh/src/emitters/` — that's **horizontal thinking**. Emitters belong in their domain's vertical slices.

**Emitters are already correctly located** in their command slices:
```
apps/manage_capabilities/src/announce_capability/capability_announced_v1_to_mesh.erl
apps/manage_social/src/follow_agent/agent_followed_v1_to_mesh.erl
apps/manage_social/src/unfollow_agent/agent_unfollowed_v1_to_mesh.erl
apps/manage_social/src/endorse_capability/capability_endorsed_v1_to_mesh.erl
apps/manage_social/src/revoke_endorsement/endorsement_revoked_v1_to_mesh.erl
apps/manage_subscriptions/src/subscribe/subscribed_v1_to_mesh.erl
apps/manage_subscriptions/src/unsubscribe/unsubscribed_v1_to_mesh.erl
apps/manage_identities/src/register_identity/identity_registered_v1_to_mesh.erl
apps/manage_identities/src/update_identity/identity_updated_v1_to_mesh.erl
apps/manage_ucan/src/grant_capability/capability_granted_v1_to_mesh.erl
apps/manage_ucan/src/revoke_capability/capability_revoked_v1_to_mesh.erl
```

**Actual task:** Ensure all emitters are supervised by their domain supervisors.

**Added to supervisors:**
- `manage_social_sup` — added `agent_unfollowed_v1_to_mesh`, `capability_endorsed_v1_to_mesh`, `endorsement_revoked_v1_to_mesh`
- `manage_identities_sup` — added `identity_updated_v1_to_mesh`

**Already supervised (no changes needed):**
- `manage_capabilities_sup` → `capability_announced_v1_to_mesh`
- `manage_subscriptions_sup` → `subscribed_v1_to_mesh`, `unsubscribed_v1_to_mesh`
- `manage_ucan_sup` → `capability_granted_v1_to_mesh`, `capability_revoked_v1_to_mesh`

---

### Phase 6: Hierarchical Identity Config ✅ COMPLETE

Added to `config/sys.config`:

```erlang
{hecate, [
    %% ... existing config ...

    %% Hierarchical Identity Configuration
    {gateway_identity, <<"mri:agent:io.macula/hecate-dev">>},

    %% Managed identities: gateway + all child service identities
    %% Listeners filter incoming mesh facts against this list (is_my_identity/1)
    {managed_identities, [
        <<"mri:agent:io.macula/hecate-dev">>
        %% Add child services as deployed:
        %% <<"mri:agent:io.macula/hecate-dev/weather">>,
        %% <<"mri:agent:io.macula/hecate-dev/translation">>
    ]}
]}
```

**Usage:** All 5 filtered listeners already use `application:get_env(hecate, managed_identities, [])` in their `is_my_identity/1` function.

---

## Files Summary

### To Delete

| File | Reason |
|------|--------|
| `apps/hecate_mesh/src/hecate_mesh_subscriber.erl` | Replaced by listeners |
| `apps/query_capabilities/src/projections/` | Flatten to `src/` |
| `apps/query_capabilities/src/queries/` | Flatten to `src/` |
| `src/hecate_api_health.erl` | Duplicate |
| `src/hecate_api_identity.erl` | Duplicate |
| `src/hecate_api_rpc.erl` | Duplicate |
| `src/hecate_api_ucan.erl` | Duplicate |

### To Create

| File | Purpose |
|------|---------|
| `apps/hecate_mesh/src/listeners/*.erl` | Individual listeners (7 files) |
| `apps/hecate_mesh/src/emitters/*.erl` | Consolidated emitters (4 files) |
| `apps/hecate_mesh/src/hecate_mesh_integration_sup.erl` | Supervisor |
| `apps/manage_social/src/record_follower/*.erl` | New command slice |
| `apps/manage_social/src/record_unfollower/*.erl` | New command slice |
| (etc. for other inbound fact handlers) | |

### To Modify

| File | Changes |
|------|---------|
| `apps/query_*/src/*_store.erl` | Add `remote_*` tables |
| `config/sys.config` | Add `managed_identities` config |
| `rebar.config` | Update deps if needed |

---

## Success Criteria

- [x] No `hecate_mesh_subscriber.erl` (deleted)
- [x] Individual listeners per concern
- [x] Emitters supervised by their domains (vertical, not consolidated)
- [x] Separate `remote_*` tables for mesh facts
- [x] New commands for "someone did X to me" patterns
- [x] Flat structure in `query_capabilities/src/`
- [x] No duplicate API files
- [x] Hierarchical identity config (`managed_identities`)
- [x] All filtering uses `is_my_identity/1` check
- [ ] All tests passing

---

## Architecture Diagram (Corrected)

```
                              MESH
                                │
           ┌────────────────────┼────────────────────┐
           │                    │                    │
           ▼                    ▼                    ▼
    ┌─────────────┐     ┌─────────────┐      ┌─────────────┐
    │  Discovery  │     │  Bilateral  │      │  Security   │
    │  Listeners  │     │  Listeners  │      │  Listeners  │
    └──────┬──────┘     └──────┬──────┘      └──────┬──────┘
           │                   │                    │
           │         is_my_identity()?     is_my_identity()?
           │                   │                    │
           ▼                   ▼                    ▼
    ┌─────────────┐     ┌─────────────┐      ┌─────────────┐
    │   Direct    │     │   COMMAND   │      │   COMMAND   │
    │ Projection  │     │      ↓      │      │      ↓      │
    │      ↓      │     │  Aggregate  │      │  Aggregate  │
    │ remote_*    │     │      ↓      │      │      ↓      │
    │   tables    │     │   EVENT     │      │   EVENT     │
    └─────────────┘     │      ↓      │      │      ↓      │
                        │  ReckonDB   │      │  ReckonDB   │
                        │      ↓      │      │      ↓      │
                        │ Projection  │      │ Projection  │
                        │      ↓      │      │      ↓      │
                        │ my_* tables │      │ recv_* tbls │
                        └─────────────┘      └─────────────┘
```

---

## Open Questions

1. Should emitters stay in domain apps or consolidate in `hecate_mesh`?
2. Retention policy for `remote_*` tables (TTL)?
3. Should `remote_*` be SQLite or ETS (cache only)?

---

## References

- [APPRENTICE_INSTRUCTIONS.md](../APPRENTICE_INSTRUCTIONS.md) — Corrected mental model
- [Cartwheel Overview](../guides/CARTWHEEL_OVERVIEW.md)
- [Projection Sequence Guide](../guides/CARTWHEEL_PROJECTION_SEQUENCE.md)
- [Write Sequence Guide](../guides/CARTWHEEL_WRITE_SEQUENCE.md)
- [Architecture Documentation](../docs/ARCHITECTURE.md)
