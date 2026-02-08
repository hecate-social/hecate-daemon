# Plan: Hecate Walking Skeleton

## Status: PLANNING

**Created:** 2026-02-08
**Goal:** End-to-end thin slice proving the Torch → Cartwheel → Agent architecture

---

## Overview

The walking skeleton implements a minimal but architecturally complete path through:

```
Torch (business endeavor)
├── initiates Cartwheel (bounded context)
├── spawns Agent (DnA Specialist)
└── tracks Telemetry (cost/metrics)
```

**Skeleton scope:**
- One hardcoded Torch
- One Cartwheel (the Torch's first context)
- One Agent (DnA Specialist only)
- Basic telemetry (token counting)

---

## Architecture: Option B (Proper Separation)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DAEMON APPS                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  manage_torches (NEW)                                                │
│  ├── Torch aggregate                                                 │
│  ├── Events: torch_initiated_v1, cartwheel_activated_v1             │
│  └── Links to: manage_cartwheels                                     │
│                                                                       │
│  manage_cartwheels (RENAME from manage_alc)                          │
│  ├── Cartwheel aggregate (existing ALC structure + torch_id)         │
│  ├── Events: cartwheel_initiated_v1, + existing phase events         │
│  └── Full phase lifecycle (DnA → AnP → TnI → DnO)                    │
│                                                                       │
│  manage_agents (NEW)                                                 │
│  ├── Agent aggregate (specialists + generalists)                     │
│  ├── Events: specialist_activated_v1, task_assigned_v1              │
│  └── Skeleton: DnA Specialist only                                   │
│                                                                       │
│  hecate_telemetry (NEW)                                              │
│  ├── SQLite storage for metrics                                      │
│  ├── LLM call instrumentation                                        │
│  └── Cost tracking per Torch                                         │
│                                                                       │
│  hecate_api (MODIFY)                                                 │
│  └── Add routes: /torch, /cartwheel, /agents, /telemetry, /cost     │
│                                                                       │
│  serve_llm (KEEP)                                                    │
│  └── Existing LLM provider routing                                   │
│                                                                       │
│  hecate_mesh (KEEP - minimal)                                        │
│  └── Mesh connection (defer mesh features for skeleton)              │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Rename manage_alc → manage_cartwheels

### Files to Rename

| Old Path | New Path |
|----------|----------|
| `apps/manage_alc/` | `apps/manage_cartwheels/` |
| `src/manage_alc.app.src` | `src/manage_cartwheels.app.src` |
| `src/manage_alc_app.erl` | `src/manage_cartwheels_app.erl` |
| `src/manage_alc_sup.erl` | `src/manage_cartwheels_sup.erl` |
| `src/alc_aggregate.erl` | `src/cartwheel_aggregate.erl` |

### Code Changes

1. **Rename module declarations** in all `.erl` files
2. **Add `torch_id`** to cartwheel aggregate state:
   ```erlang
   -record(cartwheel_state, {
       cartwheel_id :: binary() | undefined,
       torch_id :: binary() | undefined,      %% NEW
       context_name :: binary() | undefined,  %% NEW (was project_name)
       %% ... rest of existing fields
   }).
   ```
3. **Rename first event**: `project_initiated_v1` → `cartwheel_initiated_v1`
4. **Update all event types** to include `torch_id` in payload
5. **Update rebar.config** dependencies referencing manage_alc

### Query Side

| Old Path | New Path |
|----------|----------|
| `apps/query_alc/` | `apps/query_cartwheels/` |

Same pattern: rename app, modules, update projections.

---

## Phase 2: Create manage_torches

### Directory Structure

```
apps/manage_torches/
├── src/
│   ├── manage_torches.app.src
│   ├── manage_torches_app.erl
│   ├── manage_torches_sup.erl
│   ├── torch_aggregate.erl
│   ├── initiate_torch/
│   │   ├── initiate_torch_v1.erl        # Command
│   │   ├── torch_initiated_v1.erl       # Event
│   │   └── maybe_initiate_torch.erl     # Handler
│   └── activate_cartwheel/
│       ├── activate_cartwheel_v1.erl    # Command
│       ├── cartwheel_activated_v1.erl   # Event
│       └── maybe_activate_cartwheel.erl # Handler
└── rebar.config
```

### Torch Aggregate State

```erlang
-record(torch_state, {
    torch_id :: binary() | undefined,
    name :: binary() | undefined,
    brief :: binary() | undefined,
    status :: non_neg_integer(),           %% Bit flags
    repos :: [map()] | undefined,          %% Skeleton: empty list
    skills :: [binary()] | undefined,      %% Skeleton: hardcoded
    context_map :: [binary()] | undefined, %% List of context names
    active_cartwheel_id :: binary() | undefined,
    initiated_at :: non_neg_integer() | undefined,
    initiated_by :: binary() | undefined
}).

%% Status flags
-define(INITIATED,          1).   %% Torch initiated
-define(DNA_ACTIVE,         2).   %% In DnA phase (Torch-level)
-define(DNA_COMPLETE,       4).   %% Context map drafted
-define(IMPLEMENTING,       8).   %% Working on cartwheels
-define(COMPLETED,         16).   %% All cartwheels done
```

### Events

**torch_initiated_v1**
```erlang
#{
    event_type => <<"torch_initiated_v1">>,
    data => #{
        torch_id => binary(),
        name => binary(),
        brief => binary(),
        initiated_by => binary(),
        initiated_at => integer()
    }
}
```

**cartwheel_activated_v1**
```erlang
#{
    event_type => <<"cartwheel_activated_v1">>,
    data => #{
        torch_id => binary(),
        cartwheel_id => binary(),
        context_name => binary(),
        activated_at => integer()
    }
}
```

---

## Phase 3: Create manage_agents

### Directory Structure

```
apps/manage_agents/
├── src/
│   ├── manage_agents.app.src
│   ├── manage_agents_app.erl
│   ├── manage_agents_sup.erl
│   ├── agent_aggregate.erl
│   ├── activate_specialist/
│   │   ├── activate_specialist_v1.erl
│   │   ├── specialist_activated_v1.erl
│   │   └── maybe_activate_specialist.erl
│   └── assign_task/
│       ├── assign_task_v1.erl
│       ├── task_assigned_v1.erl
│       └── maybe_assign_task.erl
└── rebar.config
```

### Agent Aggregate State (Skeleton: Minimal)

```erlang
-record(agent_state, {
    agent_id :: binary() | undefined,
    torch_id :: binary() | undefined,
    agent_type :: specialist | generalist,
    role :: dna | anp | tni | dno | undefined,  %% For specialists
    status :: non_neg_integer(),
    current_task_id :: binary() | undefined,
    activated_at :: non_neg_integer() | undefined
}).

%% Status flags
-define(ACTIVATED,    1).
-define(IDLE,         2).
-define(WORKING,      4).
-define(RETIRED,      8).
```

### Skeleton Scope

For the skeleton, only implement:
- `specialist_activated_v1` — Activate DnA specialist
- `task_assigned_v1` — Assign a task to the specialist

Defer:
- Generalist pool
- Other specialists (AnP, TnI, DnO)
- Task completion, handoff

---

## Phase 4: Create hecate_telemetry

### Directory Structure

```
apps/hecate_telemetry/
├── src/
│   ├── hecate_telemetry.app.src
│   ├── hecate_telemetry_app.erl
│   ├── hecate_telemetry_sup.erl
│   ├── hecate_telemetry_store.erl    # SQLite wrapper
│   └── hecate_telemetry_collector.erl # Instrumentation
├── priv/
│   └── schema.sql                     # SQLite schema
└── rebar.config
```

### SQLite Schema

```sql
-- LLM call tracking
CREATE TABLE llm_calls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    torch_id TEXT NOT NULL,
    agent_id TEXT,
    task_id TEXT,
    model TEXT NOT NULL,
    tokens_in INTEGER NOT NULL,
    tokens_out INTEGER NOT NULL,
    cost_usd REAL,
    timestamp INTEGER NOT NULL
);

CREATE INDEX idx_llm_calls_torch ON llm_calls(torch_id, timestamp);
CREATE INDEX idx_llm_calls_agent ON llm_calls(agent_id, timestamp);

-- Agent metrics (future)
CREATE TABLE agent_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    torch_id TEXT NOT NULL,
    agent_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    labels TEXT,
    timestamp INTEGER NOT NULL
);

CREATE INDEX idx_metrics_torch ON agent_metrics(torch_id, timestamp);
```

### Skeleton Scope

- SQLite database creation
- `record_llm_call/1` function for instrumentation
- Basic query functions: `get_cost_by_torch/1`, `get_total_cost/0`

Defer:
- Prometheus export
- Agent metrics
- Detailed traces

---

## Phase 5: Modify hecate_api

### New Routes

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| GET | `/api/torch` | `hecate_api_torch` | Get current Torch |
| POST | `/api/torch/initiate` | `hecate_api_torch` | Initiate new Torch |
| GET | `/api/cartwheel` | `hecate_api_cartwheel` | Get active Cartwheel |
| GET | `/api/cartwheel/:id` | `hecate_api_cartwheel` | Get specific Cartwheel |
| GET | `/api/agents` | `hecate_api_agents` | List agents |
| GET | `/api/agents/:id` | `hecate_api_agents` | Get agent status |
| GET | `/api/telemetry/cost` | `hecate_api_telemetry` | Cost summary |
| GET | `/api/telemetry/cost/:torch_id` | `hecate_api_telemetry` | Cost by Torch |

### Skeleton Scope

Implement all routes with basic functionality. Hardcode single Torch for skeleton.

---

## Phase 6: Modify TUI

### New Commands

| Command | File | Description |
|---------|------|-------------|
| `/torch` | `torch.go` | Show current Torch, phase |
| `/cartwheel` | `cartwheel.go` | Show active Cartwheel (alias: `/cw`) |
| `/agents` | `agents.go` | Show agent swarm status |
| `/cost` | `cost.go` | Show LLM cost breakdown |

### Modify Existing

| File | Changes |
|------|---------|
| `alc.go` | Rename to `cartwheel.go`, update commands |
| `statusbar/statusbar.go` | Add Torch name, phase indicator, agent count |
| `registry.go` | Register new commands |

### Skeleton Scope

- `/torch` shows hardcoded Torch info
- `/agents` shows DnA Specialist status
- `/cost` shows token counts from telemetry
- Statusbar shows phase

---

## Phase 7: Wire It Together

### Integration Points

1. **Torch → Cartwheel**
   - `torch_initiated_v1` triggers automatic first Cartwheel creation
   - Or: manual `activate_cartwheel_v1` command

2. **Torch → Agent**
   - `torch_initiated_v1` triggers DnA Specialist activation
   - Process Manager: `on_torch_initiated_activate_dna_specialist/`

3. **LLM → Telemetry**
   - Instrument `serve_llm` to call `hecate_telemetry:record_llm_call/1`
   - Pass torch_id through LLM call context

4. **TUI → Daemon**
   - New client methods for Torch, Cartwheel, Agent, Telemetry endpoints

---

## Implementation Order

### Step 1: Rename (manage_alc → manage_cartwheels)
- [ ] Rename directories and files
- [ ] Update module names
- [ ] Add torch_id to aggregate
- [ ] Rename events (project → cartwheel)
- [ ] Update query_alc → query_cartwheels
- [ ] Update rebar.config dependencies
- [ ] Verify compilation

### Step 2: Create manage_torches
- [ ] Create app structure
- [ ] Implement torch_aggregate.erl
- [ ] Implement initiate_torch/ spoke
- [ ] Implement activate_cartwheel/ spoke
- [ ] Wire up supervisor
- [ ] Add to umbrella rebar.config
- [ ] Verify compilation

### Step 3: Create manage_agents (minimal)
- [ ] Create app structure
- [ ] Implement agent_aggregate.erl (minimal)
- [ ] Implement activate_specialist/ spoke
- [ ] Wire up supervisor
- [ ] Verify compilation

### Step 4: Create hecate_telemetry
- [ ] Create app structure
- [ ] Create SQLite schema
- [ ] Implement store module
- [ ] Implement collector module
- [ ] Wire up supervisor
- [ ] Verify compilation

### Step 5: Update hecate_api
- [ ] Add torch routes
- [ ] Add cartwheel routes
- [ ] Add agent routes
- [ ] Add telemetry routes
- [ ] Update router
- [ ] Verify compilation

### Step 6: Instrument serve_llm
- [ ] Add telemetry calls to LLM providers
- [ ] Pass torch_id through context
- [ ] Verify telemetry recording

### Step 7: Update TUI
- [ ] Add /torch command
- [ ] Rename /alc → /cartwheel
- [ ] Add /agents command
- [ ] Add /cost command
- [ ] Update statusbar
- [ ] Update client for new endpoints
- [ ] Verify build

### Step 8: Integration Testing
- [ ] Initiate Torch → Cartwheel created
- [ ] DnA Specialist activated
- [ ] LLM calls recorded to telemetry
- [ ] /cost shows accurate data
- [ ] End-to-end flow works

---

## Definition of Done

The skeleton is complete when:

1. **TUI can initiate a Torch** → `/torch init "My Project"`
2. **Cartwheel is created** → linked to Torch
3. **DnA Specialist is activated** → shows in `/agents`
4. **User can chat** → LLM calls work as before
5. **Telemetry captures costs** → `/cost` shows token usage
6. **Statusbar shows context** → Torch name, phase, agent indicator

---

## Deferred for Later

- Other specialists (AnP, TnI, DnO)
- Generalist pool
- Skill system (profiles, detection)
- Mesh distribution
- Human feedback (quick react)
- Prometheus export
- Multi-Torch support
- torch.toml parsing

---

## Files Summary

### Create

| App | Files |
|-----|-------|
| `manage_torches` | ~10 files (aggregate, 2 spokes, app/sup) |
| `manage_agents` | ~7 files (aggregate, 1 spoke, app/sup) |
| `hecate_telemetry` | ~5 files (store, collector, schema, app/sup) |

### Rename

| From | To |
|------|-----|
| `apps/manage_alc/` | `apps/manage_cartwheels/` |
| `apps/query_alc/` | `apps/query_cartwheels/` |

### Modify

| App | Changes |
|-----|---------|
| `hecate_api` | Add 8 new routes |
| `serve_llm` | Add telemetry instrumentation |
| TUI | Add 4 commands, update statusbar |

---

## Notes

- **Event naming**: All aggregates start with `{aggregate}_initiated_v1`
- **Torch ID**: Passed through all operations for attribution
- **Skeleton = thin**: Minimal implementation, but correct structure
- **No shortcuts**: Proper event sourcing, proper separation

---

## References

- `plans/VISION_HECATE_ECOSYSTEM.md` — Full ecosystem vision
- `plans/METHODOLOGY_CARTWHEEL_SKELETON.md` — Cartwheel pattern
- `hecate-agents/skills/ANTIPATTERNS.md` — Rules to follow
