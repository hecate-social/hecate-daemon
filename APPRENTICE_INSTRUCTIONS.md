# Apprentice Instructions: Hecate Architecture Refactor

**From:** Hecate (Co-Architect) & Raf (Principal Architect)
**To:** Claude (Apprentice)
**Date:** 2026-02-02
**Priority:** HIGH

---

## 🔥 READ THIS FIRST

Your current implementation has solid foundations. The domain structure, vertical slicing, and CQRS patterns are good. However, the **mesh integration is architecturally incorrect** and the **mental model needs adjustment**.

This document provides corrected understanding and specific refactoring tasks.

---

## Part 1: Corrected Mental Model

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

No special registration protocol. No HTTP calls. Direct function calls.

### Identity Model: Hierarchical

```
Gateway Identity:  mri:agent:io.macula/my-gateway

Service Identities (children):
├── mri:agent:io.macula/my-gateway/weather
├── mri:agent:io.macula/my-gateway/translation
└── mri:agent:io.macula/my-gateway/data-api
```

---

## Part 2: Mesh Integration Doctrine

### CRITICAL: FACTS ≠ EVENTS

You already documented this in CLAUDE.md. Now implement it.

| Concept | What It Is | Where It Lives |
|---------|-----------|----------------|
| **EVENT** | Internal domain event (past tense) | ReckonDB, within this node |
| **FACT** | External integration message (past tense) | Mesh, between agents |
| **COMMAND** | Intention to change state (imperative) | Within this node |
| **HOPE** | RPC request (present tense, optimistic) | Mesh, between agents |
| **FEEDBACK** | RPC response | Mesh, between agents |

### The Four Mesh Components

Replace `hecate_mesh_subscriber` (the god-module) with these:

| Component | Purpose | Flow |
|-----------|---------|------|
| **EMITTER** | Publishes to mesh | Domain EVENT → converts to → FACT → Mesh |
| **LISTENER** | Receives from mesh | Mesh FACT → (filter) → COMMAND → Aggregate |
| **REQUESTER** | Initiates RPC | Sends HOPE → receives FEEDBACK |
| **RESPONDER** | Handles RPC | Receives HOPE → COMMAND → Aggregate → FEEDBACK |

### Treatment of Incoming FACTs

Your analysis was correct. Here's the definitive treatment matrix:

#### Category 1: Discovery/Caching (Direct Projection)

These are facts about OTHER agents. Cache them for queries. No domain participation needed.

| Fact | Treatment | Target Table |
|------|-----------|--------------|
| `capability.announced` | Direct Projection | `remote_capabilities` |
| `capability.revised` | Direct Projection | `remote_capabilities` |
| `identity.registered` | Direct Projection | `remote_identities` |
| `identity.updated` | Direct Projection | `remote_identities` |

**Note:** These go to SEPARATE tables from local data (remote_* prefix).

#### Category 2: Bilateral Relationships (Filtered → CMD Flow)

These are only relevant when THIS gateway/service is the target.

| Fact | Filter | Treatment | Target |
|------|--------|-----------|--------|
| `social.followed` | target == MY_ID | LISTENER → `record_follower_v1` | `my_followers` |
| `social.unfollowed` | target == MY_ID | LISTENER → `record_unfollower_v1` | `my_followers` |
| `social.endorsed` | owner == MY_ID | LISTENER → `record_endorsement_v1` | `my_endorsements` |
| `social.endorsement_revoked` | owner == MY_ID | LISTENER → `record_endorsement_revoked_v1` | `my_endorsements` |
| `subscription.subscribed` | owner == MY_ID | LISTENER → `record_subscriber_v1` | `my_subscribers` |
| `subscription.unsubscribed` | owner == MY_ID | LISTENER → `record_unsubscriber_v1` | `my_subscribers` |

#### Category 3: Disputes (Filtered → CMD Flow)

| Fact | Filter | Treatment |
|------|--------|-----------|
| `dispute.flagged` | accused == MY_ID | LISTENER → `record_dispute_against_me_v1` |
| `dispute.resolved` | accused == MY_ID | LISTENER → `record_dispute_resolution_v1` |

#### Category 4: Security-Critical (Filtered → CMD Flow)

| Fact | Filter | Treatment |
|------|--------|-----------|
| `ucan.granted` | audience == MY_ID | LISTENER → `receive_capability_v1` |
| `ucan.revoked` | affects my tokens | LISTENER → `capability_revocation_received_v1` |

#### Category 5: REMOVE

| Fact | Reason |
|------|--------|
| `rpc.tracked` | Each agent tracks their own. No need to subscribe to all. |

---

## Part 3: Refactoring Tasks

### Task 1: Separate Read Models (Local vs Remote)

**Current:** Single table for capabilities, identities, etc.
**Required:** Separate tables for local vs remote data.

```sql
-- Local (my data, from my events)
CREATE TABLE capabilities (...);
CREATE TABLE identities (...);
CREATE TABLE followers (...);  -- People I follow

-- Remote (their data, from mesh facts)
CREATE TABLE remote_capabilities (...);
CREATE TABLE remote_identities (...);
CREATE TABLE my_followers (...);  -- People who follow ME
```

**Files to modify:**
- `apps/query_*/src/*_store.erl` — Add remote_* tables
- Create new projection modules for mesh facts → remote_* tables

---

### Task 2: Replace hecate_mesh_subscriber

**Delete:** `apps/hecate_mesh/src/hecate_mesh_subscriber.erl`

**Create:** Individual listeners per concern:

```
apps/hecate_mesh/src/
├── listeners/
│   ├── remote_capabilities_listener.erl   # Direct projection
│   ├── remote_identities_listener.erl     # Direct projection
│   ├── follower_events_listener.erl       # Filtered → CMD
│   ├── endorsement_events_listener.erl    # Filtered → CMD
│   ├── subscriber_events_listener.erl     # Filtered → CMD
│   ├── dispute_events_listener.erl        # Filtered → CMD
│   └── ucan_events_listener.erl           # Filtered → CMD (CRITICAL)
├── emitters/
│   ├── capability_emitter.erl             # EVENT → FACT
│   ├── identity_emitter.erl
│   ├── social_emitter.erl
│   └── subscription_emitter.erl
└── hecate_mesh_integration_sup.erl        # Supervisor for all
```

---

### Task 3: Implement Listener Pattern

```erlang
%% apps/hecate_mesh/src/listeners/follower_events_listener.erl
-module(follower_events_listener).
-behaviour(gen_server).

-export([start_link/0, init/1, handle_info/2]).

-define(MY_IDENTITIES, application:get_env(hecate, managed_identities, [])).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Subscribe to mesh topic
    hecate_mesh:subscribe(<<"hecate.social.followed">>, self()),
    hecate_mesh:subscribe(<<"hecate.social.unfollowed">>, self()),
    {ok, #{}}.

handle_info({mesh_fact, <<"hecate.social.followed">>, Fact}, State) ->
    TargetId = maps:get(target_id, Fact),
    case is_my_identity(TargetId) of
        true ->
            %% This is about ME - go through CMD flow
            Cmd = record_follower_v1:new(
                maps:get(follower_id, Fact),
                TargetId,
                maps:get(followed_at, Fact)
            ),
            manage_social:dispatch(Cmd);
        false ->
            %% Not about me - ignore
            ok
    end,
    {noreply, State};

handle_info({mesh_fact, <<"hecate.social.unfollowed">>, Fact}, State) ->
    %% Similar pattern...
    {noreply, State}.

is_my_identity(Identity) ->
    lists:member(Identity, ?MY_IDENTITIES).
```

---

### Task 4: Implement Emitter Pattern

```erlang
%% apps/hecate_mesh/src/emitters/capability_emitter.erl
-module(capability_emitter).
-behaviour(gen_server).

-export([start_link/0, init/1, handle_info/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Subscribe to LOCAL event store
    {ok, _SubId} = reckon_evoq_adapter:subscribe(
        manage_capabilities_db,
        event_type,
        <<"capability_announced_v1">>,
        <<"emitter_capability_announced">>,
        #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #{}}.

handle_info({event, #evoq_event{data = EventData}}, State) ->
    %% Convert domain EVENT to mesh FACT
    Fact = event_to_fact(EventData),
    
    %% Publish to mesh
    hecate_mesh:publish(<<"hecate.capability.announced">>, Fact),
    
    {noreply, State}.

event_to_fact(EventData) ->
    %% Transform internal event structure to public fact contract
    #{
        capability_mri => maps:get(capability_mri, EventData),
        agent_identity => maps:get(agent_identity, EventData),
        description => maps:get(description, EventData),
        tags => maps:get(tags, EventData),
        announced_at => erlang:system_time(millisecond)
    }.
```

---

### Task 5: New Commands for Incoming FACTs

Create new commands/events/handlers for recording external facts that affect us:

```
apps/manage_social/src/
├── follow_agent/              # Existing: I follow someone
├── unfollow_agent/            # Existing: I unfollow someone
├── record_follower/           # NEW: Someone followed me
│   ├── record_follower_v1.erl
│   ├── follower_recorded_v1.erl
│   └── maybe_record_follower.erl
└── record_unfollower/         # NEW: Someone unfollowed me
    ├── record_unfollower_v1.erl
    ├── unfollower_recorded_v1.erl
    └── maybe_record_unfollower.erl
```

Similar pattern for:
- `record_endorsement` / `record_endorsement_revoked`
- `record_subscriber` / `record_unsubscriber`
- `record_dispute_against_me` / `record_dispute_resolution`
- `receive_capability` / `capability_revocation_received`

---

### Task 6: Fix Horizontal Violations

#### 6a: Flatten query_capabilities

**Current:**
```
apps/query_capabilities/src/
├── projections/
│   └── capability_announced_v1_to_capabilities.erl
└── queries/
    ├── find_capability.erl
    └── list_capabilities.erl
```

**Required:**
```
apps/query_capabilities/src/
├── capability_announced_v1_to_capabilities.erl
├── find_capability.erl
├── list_capabilities.erl
└── ... (all flat)
```

Other query apps do this correctly. Match their structure.

#### 6b: Consolidate API Files

**Current:** Duplicate files in `src/` and `apps/hecate_api/src/`
**Required:** All API handlers in `apps/hecate_api/src/` only

Remove from root `src/`:
- `hecate_api_health.erl` (duplicate)
- `hecate_api_identity.erl` (duplicate)
- `hecate_api_rpc.erl` (duplicate)
- `hecate_api_ucan.erl` (duplicate)

---

### Task 7: Hierarchical Identity Support

Add configuration for managed identities:

```erlang
%% config/sys.config
{hecate, [
    {gateway_identity, <<"mri:agent:io.macula/my-gateway">>},
    {managed_identities, [
        <<"mri:agent:io.macula/my-gateway">>,
        <<"mri:agent:io.macula/my-gateway/weather">>,
        <<"mri:agent:io.macula/my-gateway/translation">>
    ]}
]}
```

Use this list when filtering incoming FACTs ("is this about ME?").

---

## Part 4: Priority Order

1. **Task 6** — Fix horizontal violations (quick wins, clean up)
2. **Task 1** — Separate read models (foundation for correct data flow)
3. **Task 5** — New commands for incoming FACTs (domain modeling)
4. **Task 2 & 3** — Replace subscriber with listeners (correct mesh integration)
5. **Task 4** — Implement emitters (complete the picture)
6. **Task 7** — Hierarchical identity support

---

## Part 5: Success Criteria

When complete:

- [ ] No `hecate_mesh_subscriber.erl` (deleted)
- [ ] Individual listeners per concern
- [ ] Individual emitters per domain
- [ ] Separate `remote_*` tables for mesh facts
- [ ] New commands for "someone did X to me" patterns
- [ ] Flat structure in `query_capabilities/src/`
- [ ] No duplicate API files
- [ ] Hierarchical identity config

---

## Questions?

If anything is unclear, ask. Do not guess. Do not take shortcuts.

The architecture we're building will serve many agents. Getting the foundations right matters.

*— Hecate, Co-Architect* 🔥🗝️🔥
