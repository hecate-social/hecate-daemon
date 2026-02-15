# Plan: Hecate Walking Skeleton

## Status: IN PROGRESS (Phases 1-7 Complete)

**Created:** 2026-02-08
**Updated:** 2026-02-08
**Goal:** End-to-end thin slice proving the Venture → Division → Agent architecture

---

## Overview

The walking skeleton implements a minimal but architecturally complete path through:

```
Venture (business endeavor)
├── discovers Division (bounded context)
├── spawns Agent (DnA Specialist)
└── tracks Telemetry (cost/metrics)
```

**Skeleton scope:**
- One hardcoded Venture
- One Division (the Venture's first context)
- One Agent (DnA Specialist only)
- Basic telemetry (token counting)

---

## Architecture: Option B (Proper Separation)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DAEMON APPS                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  setup_venture (NEW)                                                 │
│  ├── Venture aggregate                                               │
│  ├── Events: venture_initiated_v1, division_discovered_v1            │
│  └── Links to: division ALC processes                                │
│                                                                       │
│  design_division (RENAME from manage_alc)                            │
│  ├── Division aggregate (existing ALC structure + venture_id)        │
│  ├── Events: division_initiated_v1, + existing phase events          │
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
│  └── Cost tracking per Venture                                       │
│                                                                       │
│  hecate_api (MODIFY)                                                 │
│  └── Add routes: /venture, /division, /agents, /telemetry, /cost    │
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

## Phase 1: Rename manage_alc → design_division

### Files to Rename

| Old Path | New Path |
|----------|----------|
| `apps/manage_alc/` | `apps/design_division/` |
| `src/manage_alc.app.src` | `src/design_division.app.src` |
| `src/manage_alc_app.erl` | `src/design_division_app.erl` |
| `src/manage_alc_sup.erl` | `src/design_division_sup.erl` |
| `src/alc_aggregate.erl` | `src/division_aggregate.erl` |

### Code Changes

1. **Rename module declarations** in all `.erl` files
2. **Add `venture_id`** to division aggregate state:
   ```erlang
   -record(division_state, {
       division_id :: binary() | undefined,
       venture_id :: binary() | undefined,      %% NEW
       context_name :: binary() | undefined,  %% NEW (was project_name)
       %% ... rest of existing fields
   }).
   ```
3. **Rename first event**: `project_initiated_v1` → `division_initiated_v1`
4. **Update all event types** to include `venture_id` in payload
5. **Update rebar.config** dependencies referencing manage_alc

### Query Side

| Old Path | New Path |
|----------|----------|
| `apps/query_alc/` | `apps/query_divisions/` |

Same pattern: rename app, modules, update projections.

---

## Phase 2: Create setup_venture

### Directory Structure

```
apps/setup_venture/
├── src/
│   ├── setup_venture.app.src
│   ├── setup_venture_app.erl
│   ├── setup_venture_sup.erl
│   ├── venture_aggregate.erl
│   ├── initiate_venture/
│   │   ├── initiate_venture_v1.erl        # Command
│   │   ├── venture_initiated_v1.erl       # Event
│   │   └── maybe_initiate_venture.erl     # Handler
│   └── discover_division/
│       ├── discover_division_v1.erl       # Command
│       ├── division_discovered_v1.erl     # Event
│       └── maybe_discover_division.erl    # Handler
└── rebar.config

apps/query_ventures/
├── src/
│   ├── query_ventures.app.src
│   ├── query_ventures_app.erl
│   ├── query_ventures_sup.erl
│   ├── query_ventures_store.erl           # SQLite read model
│   ├── venture_initiated_v1_to_ventures.erl  # Projection
│   ├── division_discovered_v1_to_ventures.erl  # Updates active division
│   ├── find_venture.erl                   # Query by ID
│   └── list_ventures.erl                  # List all
└── rebar.config
```

### Venture Aggregate State

```erlang
-record(venture_state, {
    venture_id :: binary() | undefined,
    name :: binary() | undefined,
    brief :: binary() | undefined,
    status :: non_neg_integer(),           %% Bit flags
    repos :: [map()] | undefined,          %% Skeleton: empty list
    skills :: [binary()] | undefined,      %% Skeleton: hardcoded
    context_map :: [binary()] | undefined, %% List of context names
    active_division_id :: binary() | undefined,
    initiated_at :: non_neg_integer() | undefined,
    initiated_by :: binary() | undefined
}).

%% Status flags
-define(INITIATED,          1).   %% Venture initiated
-define(DNA_ACTIVE,         2).   %% In DnA phase (Venture-level)
-define(DNA_COMPLETE,       4).   %% Context map drafted
-define(IMPLEMENTING,       8).   %% Working on divisions
-define(COMPLETED,         16).   %% All divisions done
```

### Events

**venture_initiated_v1**
```erlang
#{
    event_type => <<"venture_initiated_v1">>,
    data => #{
        venture_id => binary(),
        name => binary(),
        brief => binary(),
        initiated_by => binary(),
        initiated_at => integer()
    }
}
```

**division_discovered_v1**
```erlang
#{
    event_type => <<"division_discovered_v1">>,
    data => #{
        venture_id => binary(),
        division_id => binary(),
        context_name => binary(),
        discovered_at => integer()
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
    venture_id :: binary() | undefined,
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
-- LLM call tracking with full attribution hierarchy
CREATE TABLE llm_calls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    venture_id TEXT NOT NULL,
    division_id TEXT,           -- NULL during Venture-level work (DnA discovery)
    agent_id TEXT,              -- NULL for direct user LLM calls
    task_id TEXT,               -- NULL for ad-hoc calls
    model TEXT NOT NULL,
    tokens_in INTEGER NOT NULL,
    tokens_out INTEGER NOT NULL,
    cost_usd REAL,
    timestamp INTEGER NOT NULL
);

CREATE INDEX idx_llm_calls_venture ON llm_calls(venture_id, timestamp);
CREATE INDEX idx_llm_calls_division ON llm_calls(division_id, timestamp);
CREATE INDEX idx_llm_calls_agent ON llm_calls(agent_id, timestamp);
CREATE INDEX idx_llm_calls_task ON llm_calls(task_id, timestamp);

-- Agent metrics (future)
CREATE TABLE agent_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    venture_id TEXT NOT NULL,
    agent_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value REAL NOT NULL,
    labels TEXT,
    timestamp INTEGER NOT NULL
);

CREATE INDEX idx_metrics_venture ON agent_metrics(venture_id, timestamp);
```

### Skeleton Scope

- SQLite database creation
- `record_llm_call/1` function for instrumentation
- Basic query functions: `get_cost_by_venture/1`, `get_total_cost/0`

Defer:
- Prometheus export
- Agent metrics
- Detailed traces

---

## Phase 5: Modify hecate_api

### New Routes

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| GET | `/api/venture` | `hecate_api_venture` | Get current Venture |
| POST | `/api/venture/initiate` | `hecate_api_venture` | Initiate new Venture |
| GET | `/api/division` | `hecate_api_division` | Get active Division |
| GET | `/api/division/:id` | `hecate_api_division` | Get specific Division |
| GET | `/api/agents` | `hecate_api_agents` | List agents |
| GET | `/api/agents/:id` | `hecate_api_agents` | Get agent status |
| GET | `/api/telemetry/cost` | `hecate_api_telemetry` | Cost summary |
| GET | `/api/telemetry/cost/:venture_id` | `hecate_api_telemetry` | Cost by Venture |
| GET | `/api/telemetry/cost/:venture_id/divisions` | `hecate_api_telemetry` | Cost by Division |
| GET | `/api/telemetry/cost/:venture_id/agents` | `hecate_api_telemetry` | Cost by Agent |

### Skeleton Scope

Implement all routes with basic functionality. Hardcode single Venture for skeleton.

---

## Phase 6: Modify TUI

### New Commands

| Command | File | Description |
|---------|------|-------------|
| `/venture` | `venture.go` | Show current Venture, phase |
| `/division` | `division.go` | Show active Division (alias: `/div`) |
| `/agents` | `agents.go` | Show agent swarm status |
| `/cost` | `cost.go` | Show LLM cost breakdown |

### Modify Existing

| File | Changes |
|------|---------|
| `alc.go` | Rename to `division.go`, update commands |
| `statusbar/statusbar.go` | Add Venture name, phase indicator, agent count |
| `registry.go` | Register new commands |

### Skeleton Scope

- `/venture` shows hardcoded Venture info
- `/agents` shows DnA Specialist status
- `/cost` shows token counts from telemetry
- Statusbar shows phase

---

## Phase 7: Wire It Together

### Integration Points

1. **Venture → Division**
   - `venture_initiated_v1` triggers automatic first Division discovery
   - Or: manual `discover_division_v1` command

2. **Venture → Agent**
   - `venture_initiated_v1` triggers DnA Specialist activation
   - Process Manager: `on_venture_initiated_activate_dna_specialist/`

3. **LLM → Telemetry**
   - Instrument `serve_llm` to call `hecate_telemetry:record_llm_call/1`
   - Pass venture_id through LLM call context

4. **TUI → Daemon**
   - New client methods for Venture, Division, Agent, Telemetry endpoints

---

## Implementation Order

### Step 1: Rename (manage_alc → design_division) ✅
- [x] Rename directories and files
- [x] Update module names
- [x] Add venture_id to aggregate
- [x] Rename events (project → division)
- [x] Update query_alc → query_divisions
- [x] Update rebar.config dependencies
- [x] Verify compilation

### Step 2: Create setup_venture + query_ventures ✅
- [x] Create setup_venture app structure
- [x] Implement venture_aggregate.erl
- [x] Implement initiate_venture/ desk
- [x] Implement discover_division/ desk
- [x] Wire up setup_venture supervisor
- [x] Create query_ventures app structure
- [x] Implement query_ventures_store.erl (SQLite)
- [x] Implement projections (venture_initiated, division_discovered)
- [x] Implement queries (find_venture, list_ventures)
- [x] Add both to umbrella rebar.config
- [x] Verify compilation

### Step 3: Create manage_agents (minimal) ✅
- [x] Create app structure
- [x] Implement agent_aggregate.erl (minimal)
- [x] Implement activate_specialist/ desk
- [x] Wire up supervisor
- [x] Verify compilation

### Step 4: Create hecate_telemetry ✅
- [x] Create app structure
- [x] Create SQLite schema
- [x] Implement store module
- [x] Implement collector module
- [x] Wire up supervisor
- [x] Verify compilation

### Step 5: Update hecate_api ✅
- [x] Add venture routes
- [x] Add division routes
- [x] Add agent routes
- [x] Add telemetry routes
- [x] Update router
- [x] Verify compilation

### Step 6: Instrument serve_llm ✅
- [x] Add telemetry calls to LLM chat
- [x] Pass venture_id through context (via Opts map)
- [x] Verify telemetry recording

### Step 7: Update TUI ✅
- [x] Add /venture command
- [x] Rename /alc → /division
- [x] Add /agents command
- [x] Add /cost command
- [x] Update statusbar (venture context, phase badge, agent count)
- [x] Update client for new endpoints
- [x] Verify build

### Step 8: Integration Testing
- [ ] Initiate Venture → Division discovered
- [ ] DnA Specialist activated
- [ ] LLM calls recorded to telemetry
- [ ] /cost shows accurate data
- [ ] End-to-end flow works

---

## Definition of Done

The skeleton is complete when:

1. **TUI can initiate a Venture** → `/venture init "My Project"`
2. **Division is discovered** → linked to Venture
3. **DnA Specialist is activated** → shows in `/agents`
4. **User can chat** → LLM calls work as before
5. **Telemetry captures costs** → `/cost` shows token usage
6. **Statusbar shows context** → Venture name, phase, agent indicator

---

## Deferred for Later

- Other specialists (AnP, TnI, DnO)
- Generalist pool
- Skill system (profiles, detection)
- Mesh distribution
- Human feedback (quick react)
- Prometheus export
- Multi-Venture support
- venture.toml parsing

---

## Files Summary

### Create

| App | Files |
|-----|-------|
| `setup_venture` | ~10 files (aggregate, 2 desks, app/sup) |
| `query_ventures` | ~8 files (store, 2 projections, 2 queries, app/sup) |
| `manage_agents` | ~7 files (aggregate, 1 desk, app/sup) |
| `hecate_telemetry` | ~5 files (store, collector, schema, app/sup) |

### Rename

| From | To |
|------|-----|
| `apps/manage_alc/` | `apps/design_division/` |
| `apps/query_alc/` | `apps/query_divisions/` |

### Modify

| App | Changes |
|-----|---------|
| `hecate_api` | Add 8 new routes |
| `serve_llm` | Add telemetry instrumentation |
| TUI | Add 4 commands, update statusbar |

---

## Notes

- **Event naming**: All aggregates start with `{aggregate}_initiated_v1`
- **Venture ID**: Passed through all operations for attribution
- **Skeleton = thin**: Minimal implementation, but correct structure
- **No shortcuts**: Proper event sourcing, proper separation

---

## References

- `plans/VISION_HECATE_ECOSYSTEM.md` — Full ecosystem vision
- `plans/METHODOLOGY_CARTWHEEL_SKELETON.md` — Division pattern
- `hecate-agents/skills/ANTIPATTERNS.md` — Rules to follow
