# Methodology: Division & Walking Skeleton

> **Note:** This file was originally named `METHODOLOGY_CARTWHEEL_SKELETON.md`. The filename is preserved to avoid breaking cross-references, but the content uses current terminology (Division/Desk).

## Status: DRAFT (2026-02-08)

This document describes the Division architecture pattern and Walking Skeleton implementation approach used in the Hecate ecosystem.

---

## Overview

The Hecate development methodology combines two powerful patterns:

1. **Division** - A bounded context organized as a hub with desks (vertical slices)
2. **Walking Skeleton** - Thin end-to-end implementation first, then flesh out

Together, they ensure:
- Clear domain boundaries
- Always-deployable code
- Incremental progress
- Architectural proof early

---

## The Division Pattern

### Concept

A **Division** represents one bounded context as a hub-and-desk structure:

```
                    ┌─────────┐
                    │   HUB   │
                    │(context)│
                    └────┬────┘
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
   ┌──────────┐   ┌──────────┐   ┌──────────┐
   │  DESK    │   │  DESK    │   │  DESK    │
   │ (slice)  │   │ (slice)  │   │ (slice)  │
   └──────────┘   └──────────┘   └──────────┘
```

### Hub

The **Hub** is the central coordinator:
- Aggregate root (for command contexts)
- Main query handler (for query contexts)
- Shared state and invariants
- Entry point for the context

### Desks

Each **Desk** is a vertical slice:
- One command OR one query
- All layers included (handler, events, projections)
- Self-contained and independently testable
- Connects to hub for coordination

### Desk Types

| Type | Purpose | Produces |
|------|---------|----------|
| **Command Desk** | Changes state | Events |
| **Query Desk** | Reads state | Data |
| **Listener Desk** | Reacts to external events | Commands |
| **Emitter Desk** | Publishes to external systems | Facts |

---

## Division Anatomy

### Command Context Example

```
DIVISION: manage_capabilities

Hub: capability_aggregate

Desks:
├── announce_capability/     (Command)
│   ├── announce_capability_v1.erl
│   ├── capability_announced_v1.erl
│   └── maybe_announce_capability.erl
│
├── withdraw_capability/     (Command)
│   ├── withdraw_capability_v1.erl
│   ├── capability_withdrawn_v1.erl
│   └── maybe_withdraw_capability.erl
│
├── mesh_capability_listener/  (Listener)
│   ├── mesh_capability_listener_sup.erl
│   └── mesh_capability_listener.erl
│
└── capability_mesh_emitter/   (Emitter)
    └── capability_mesh_emitter.erl
```

### Query Context Example

```
DIVISION: query_capabilities

Hub: capabilities_read_model

Desks:
├── find_capability/         (Query)
│   └── find_capability.erl
│
├── list_capabilities/       (Query)
│   └── list_capabilities.erl
│
├── search_capabilities/     (Query)
│   └── search_capabilities.erl
│
└── capability_projections/  (Projections)
    ├── capability_announced_to_capabilities.erl
    └── capability_withdrawn_to_capabilities.erl
```

---

## Desk Structure

### Command Desk

```
desk: record_interaction/
├── record_interaction_v1.erl       # Command definition
├── interaction_recorded_v1.erl     # Event definition
├── maybe_record_interaction.erl    # Handler (business logic)
└── record_interaction_test.erl     # Tests
```

**Command Module:**
```erlang
-module(record_interaction_v1).
-export([new/3, to_map/1, from_map/1]).

-record(record_interaction_v1, {
    agent_id :: binary(),
    interaction_type :: binary(),
    metadata :: map()
}).

new(AgentId, Type, Metadata) ->
    #record_interaction_v1{
        agent_id = AgentId,
        interaction_type = Type,
        metadata = Metadata
    }.

to_map(#record_interaction_v1{} = Cmd) ->
    #{
        agent_id => Cmd#record_interaction_v1.agent_id,
        interaction_type => Cmd#record_interaction_v1.interaction_type,
        metadata => Cmd#record_interaction_v1.metadata
    }.
```

**Event Module:**
```erlang
-module(interaction_recorded_v1).
-export([new/4, to_map/1, from_map/1]).

-record(interaction_recorded_v1, {
    interaction_id :: binary(),
    agent_id :: binary(),
    interaction_type :: binary(),
    recorded_at :: integer()
}).
```

**Handler Module:**
```erlang
-module(maybe_record_interaction).
-export([handle/2]).

handle(#record_interaction_v1{} = Cmd, State) ->
    %% Validate
    case validate(Cmd, State) of
        ok ->
            Event = interaction_recorded_v1:new(
                generate_id(),
                Cmd#record_interaction_v1.agent_id,
                Cmd#record_interaction_v1.interaction_type,
                erlang:system_time(millisecond)
            ),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.
```

### Query Desk

```
desk: find_capability/
├── find_capability.erl      # Query implementation
└── find_capability_test.erl # Tests
```

```erlang
-module(find_capability).
-export([execute/1]).

execute(#{capability_id := Id}) ->
    case capabilities_read_model:get(Id) of
        {ok, Capability} -> {ok, Capability};
        not_found -> {error, not_found}
    end.
```

---

## Walking Skeleton

### Concept

A **Walking Skeleton** is the thinnest possible end-to-end implementation:

> "A Walking Skeleton is a tiny implementation of the system that performs a small end-to-end function. It need not use the final architecture, but it should link together the main architectural components."
> — Alistair Cockburn

### Purpose

1. **Prove the architecture** - All components connect
2. **Enable deployment** - Something works from day 1
3. **Reduce risk** - Find integration issues early
4. **Enable parallel work** - Skeleton provides interfaces

### Skeleton vs Real Implementation

| Aspect | Skeleton | Fleshed Out |
|--------|----------|-------------|
| **Functionality** | Minimal/hardcoded | Complete |
| **Data** | Dummy/static | Real |
| **Validation** | None/basic | Full |
| **Error handling** | Happy path only | All cases |
| **Tests** | Existence tests | Full coverage |
| **Performance** | Ignored | Optimized |

---

## Walking Skeleton Process

### Step 1: Identify All Desks

```markdown
# Skeleton Plan: geo_check

## Desks to Skeleton
- [ ] check_ip (Command)
- [ ] reload_config (Command)
- [ ] get_status (Query)

## Integration Points
- [ ] API endpoint → check_ip
- [ ] CLI command → reload_config
- [ ] Status endpoint → get_status
```

### Step 2: Implement Skeleton for Each Desk

**check_ip skeleton:**
```erlang
-module(maybe_check_ip).
-export([handle/2]).

%% SKELETON: Always returns allowed
handle(_Cmd, _State) ->
    Event = ip_checked_v1:new(<<"0.0.0.0">>, allowed, <<"SKELETON">>),
    {ok, [Event]}.
```

**reload_config skeleton:**
```erlang
-module(maybe_reload_config).
-export([handle/2]).

%% SKELETON: Just logs
handle(_Cmd, _State) ->
    logger:info("SKELETON: Config reload requested"),
    Event = config_reloaded_v1:new(#{}),
    {ok, [Event]}.
```

**get_status skeleton:**
```erlang
-module(get_status).
-export([execute/1]).

%% SKELETON: Returns dummy status
execute(_Query) ->
    {ok, #{
        mode => blocklist,
        blocked_countries => [],
        db_loaded => false,
        skeleton => true  %% Flag indicating skeleton
    }}.
```

### Step 3: Wire Up Integration Points

```erlang
%% API Handler
handle_check_ip(Req, State) ->
    %% Parse IP from request
    IP = get_ip_from_request(Req),

    %% Dispatch command (skeleton will handle)
    Cmd = check_ip_v1:new(IP),
    Result = evoq:dispatch(geo_check, Cmd),

    %% Return response
    respond(Result, Req, State).
```

### Step 4: Deploy Skeleton

```bash
# Build
rebar3 release

# Deploy to dev
./deploy-dev.sh

# Verify
curl http://localhost:4444/api/geo/status
# {"mode":"blocklist","blocked_countries":[],"db_loaded":false,"skeleton":true}

curl -X POST http://localhost:4444/api/geo/check -d '{"ip":"1.2.3.4"}'
# {"allowed":true,"skeleton":true}
```

### Step 5: Flesh Out Incrementally

```markdown
# Flesh-Out Tracker: geo_check

## check_ip
- [x] Skeleton: always allowed
- [ ] Load GeoIP database
- [ ] Parse IP address formats
- [ ] Lookup country code
- [ ] Check blocklist/allowlist
- [ ] Return real result
- [ ] Add comprehensive tests

## reload_config
- [x] Skeleton: log only
- [ ] Read environment variables
- [ ] Parse YAML config file
- [ ] Validate configuration
- [ ] Hot-reload database
- [ ] Emit config_reloaded event

## get_status
- [x] Skeleton: dummy data
- [ ] Read actual config
- [ ] Check database loaded status
- [ ] Include country counts
- [ ] Add uptime/stats
```

---

## Templates

### Division Template

```markdown
# Division: <context_name>

## Context
<One paragraph describing this bounded context and its responsibility>

## Hub
- **Name:** <aggregate or coordinator name>
- **Responsibility:** <what it coordinates>
- **State:** <what state it maintains>

## Desks

### Desk: <name> (Command)
- **Purpose:** <what this command does>
- **Input:** <command fields>
- **Output:** <success/error>
- **Events:** <events produced>
- **Handler:** <handler module>
- **Invariants:** <business rules enforced>

### Desk: <name> (Query)
- **Purpose:** <what data this retrieves>
- **Input:** <query parameters>
- **Output:** <data shape>
- **Source:** <read model or projection>

### Desk: <name> (Listener)
- **Subscribes to:** <external event source>
- **Produces:** <commands to dispatch>
- **Handler:** <listener module>

### Desk: <name> (Emitter)
- **Triggered by:** <domain events>
- **Publishes to:** <external topic/channel>
- **Format:** <fact structure>

## Dependencies
- **Upstream:** <contexts this depends on>
- **Downstream:** <contexts that depend on this>

## Walking Skeleton

| Desk | Skeleton Behavior | Fleshed Out |
|------|-------------------|-------------|
| <name> | <minimal impl> | [ ] |

## Integration Points
- [ ] <API/CLI/UI integration>
- [ ] <Mesh integration>
- [ ] <Other context integration>
```

### Walking Skeleton Template

```markdown
# Walking Skeleton: <context_name>

## Goal
<What this skeleton proves>

## Desks

| Desk | Type | Skeleton Behavior |
|------|------|-------------------|
| <name> | CMD | <hardcoded response> |
| <name> | QRY | <static data> |

## Integration Points
- [ ] <endpoint/interface> → <desk> → <response>

## Definition of Done
- [ ] All desks callable
- [ ] End-to-end request works
- [ ] Basic tests exist
- [ ] Deployable to dev
- [ ] Skeleton flags in responses

## Excluded from Skeleton
- <real data loading>
- <full validation>
- <error handling>
- <performance optimization>

## Flesh-Out Order
1. <highest value desk first>
2. <next desk>
3. ...

## Skeleton Flags
Include `skeleton: true` in responses so consumers know this is not real:
```json
{"result": "...", "skeleton": true}
```
```

---

## Best Practices

### Do

- **Skeleton first** - Resist the urge to implement fully before integrating
- **Deploy immediately** - Skeleton should be in dev/staging from day 1
- **Mark skeleton responses** - Include flags so testers know what's real
- **One desk at a time** - Flesh out completely before moving on
- **Test at skeleton level** - Basic tests prove wiring works

### Don't

- **Don't skip desks** - Every desk needs a skeleton, even trivial ones
- **Don't over-engineer skeleton** - It's throwaway code
- **Don't block on skeleton** - It's meant to unblock parallel work
- **Don't remove skeleton flags early** - Keep until fully fleshed
- **Don't refactor during flesh-out** - Complete first, refactor after

---

## Example: Full Cycle

### 1. Receive Venture Brief
```
"We need geo-restriction to block access from sanctioned countries"
```

### 2. DnA Produces Context Map
```
Contexts: GEO_CHECK, ACCESS_CONTROL, CONFIG, AUDIT_LOG
```

### 3. Human Selects Pathway
```
Start with: GEO_CHECK (foundation)
```

### 4. AnP Designs Division
```
Desks: check_ip, reload_config, get_status
```

### 5. TnI Implements Skeleton
```
Day 1: All desks return hardcoded/dummy values
Day 1: Deployed to dev
Day 1: API endpoints wired up
```

### 6. TnI Fleshes Out
```
Day 2-3: check_ip fully implemented
Day 4: reload_config fully implemented
Day 5: get_status fully implemented
Day 5: Full test coverage
```

### 7. DnO Deploys to Production
```
Day 6: geo_check in production
Day 7: Next Division begins (ACCESS_CONTROL)
```

**Total: One week from brief to production.**

---

## References

- Cockburn, Alistair. "Walking Skeleton" - Crystal Clear methodology
- Evans, Eric. "Domain-Driven Design" - Bounded Contexts
- Vernon, Vaughn. "Implementing Domain-Driven Design" - Aggregates
- Hecate Ecosystem Vision - `VISION_HECATE_ECOSYSTEM.md`
