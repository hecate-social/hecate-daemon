# PLAN: Hecate ALC — Application Lifecycle as a Daemon Domain

**Status:** Planning
**Created:** 2026-02-05

---

## Overview

The Hecate ALC (Application Lifecycle) is the process by which Hecate agents build software. It consists of four phases that cycle:

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Discovery   │ →  │ Architecture │ →  │   Testing    │ →  │  Deployment  │
│  & Analysis  │    │  & Planning  │    │ & Implement  │    │ & Operations │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

**Phase names (final):**

| Short | Full Name | Directory |
|-------|-----------|-----------|
| DnA | Discovery & Analysis | `discovery_n_analysis/` |
| AnP | Architecture & Planning | `architecture_n_planning/` |
| TnI | Testing & Implementation | `testing_n_implementation/` |
| DnO | Deployment & Operations | `deployment_n_operations/` |

This plan turns the ALC into a **daemon domain** — one command service (`manage_alc`) and one query service (`query_alc`) that track the lifecycle of projects per-agent, per-project.

**Key insight:** 1 project = 1 ALC stream. All four phases accumulate events in a single aggregate dossier. The phases are sub-processes (organizational groupings), not separate domains.

---

## Plan Files

| File | Contents |
|------|----------|
| **PLAN_ALC_ROOT.md** (this file) | Architecture, aggregate, phases, implementation order |
| [PLAN_ALC_CMD.md](PLAN_ALC_CMD.md) | `manage_alc` command service — all desks by sub-process |
| [PLAN_ALC_QRY.md](PLAN_ALC_QRY.md) | `query_alc` query service — tables, projections, queries, API, TUI |

---

## Architecture

```
apps/manage_alc/          CMD service (ReckonDB event store)
apps/query_alc/           QRY service (SQLite read models)
hecate_api_alc.erl        REST handler (~34 endpoints under /alc/)
```

**One aggregate** (`alc_aggregate`), **four sub-processes** (`discovery_n_analysis`, `architecture_n_planning`, `testing_n_implementation`, `deployment_n_operations`), **~24 desks**, **no emitters** (ALC is internal — no mesh publishing for now).

### Stream Design

**Stream pattern:** `alc-{project_id}`

One stream per project accumulates ALL events from ALL phases. The aggregate is the project's complete lifecycle dossier.

```
Stream: alc-weather-service
├── project_initiated_v1          (orchestration)
├── discovery_started_v1          (DnA)
├── finding_recorded_v1           (DnA)
├── finding_recorded_v1           (DnA)
├── term_defined_v1               (DnA)
├── discovery_completed_v1        (DnA)
├── architecture_started_v1       (AnP)
├── dossier_defined_v1            (AnP)
├── desk_inventoried_v1          (AnP)
├── plan_drafted_v1               (AnP)
├── plan_approved_v1              (AnP)
├── architecture_completed_v1     (AnP)
├── testing_started_v1            (TnI)
├── skeleton_scaffolded_v1        (TnI)
├── desk_implemented_v1          (TnI)
├── build_verified_v1             (TnI)
├── testing_completed_v1          (TnI)
├── deployment_started_v1         (DnO)
├── release_deployed_v1           (DnO)
├── ...
└── project_completed_v1          (orchestration)
```

---

## Aggregate: `alc_aggregate`

### Status Bit Flags

```erlang
-define(INITIATED,            1).     %% 2^0  — Project exists
-define(DISCOVERY_ACTIVE,     2).     %% 2^1  — In Discovery & Analysis
-define(DISCOVERY_COMPLETE,   4).     %% 2^2  — DnA phase done
-define(ARCHITECTURE_ACTIVE,  8).     %% 2^3  — In Architecture & Planning
-define(ARCHITECTURE_COMPLETE,16).    %% 2^4  — AnP phase done
-define(TESTING_ACTIVE,      32).     %% 2^5  — In Testing & Implementation
-define(TESTING_COMPLETE,    64).     %% 2^6  — TnI phase done
-define(DEPLOYMENT_ACTIVE,  128).     %% 2^7  — In Deployment & Operations
-define(DEPLOYMENT_COMPLETE,256).     %% 2^8  — DnO phase done
-define(COMPLETED,          512).     %% 2^9  — Project completed
-define(REVISITING,        1024).     %% 2^10 — Revisiting an earlier phase
```

### Aggregate State

The aggregate tracks **counters and flags** for gate enforcement, not detailed artifacts (those live in read models).

```erlang
-record(alc_state, {
    project_id              :: binary() | undefined,
    project_name            :: binary() | undefined,
    current_phase           :: discovery_n_analysis
                             | architecture_n_planning
                             | testing_n_implementation
                             | deployment_n_operations
                             | completed
                             | undefined,
    status                  :: non_neg_integer(),

    %% DnA counters (gate: finding_count > 0, term_count > 0)
    finding_count           :: non_neg_integer(),
    term_count              :: non_neg_integer(),

    %% AnP counters (gate: dossier_count > 0, desk_count > 0, plan_approved)
    dossier_count           :: non_neg_integer(),
    desk_count             :: non_neg_integer(),
    plan_approved           :: boolean(),

    %% TnI counters (gate: skeleton_created, build_verified)
    skeleton_created        :: boolean(),
    implemented_desk_count :: non_neg_integer(),
    build_verified          :: boolean(),

    %% DnO counters (gate: deployment_count > 0, active_incidents == 0)
    deployment_count        :: non_neg_integer(),
    active_incidents        :: non_neg_integer(),

    %% Timestamps
    initiated_at            :: non_neg_integer() | undefined,
    phase_started_at        :: non_neg_integer() | undefined,
    completed_at            :: non_neg_integer() | undefined
}).
```

---

## Phase Gates

Each phase transition is enforced by the aggregate's `execute/2`:

| Transition | Gate Conditions |
|------------|-----------------|
| **DnA → AnP** | `finding_count > 0` AND `term_count > 0` |
| **AnP → TnI** | `dossier_count > 0` AND `desk_count > 0` AND `plan_approved == true` |
| **TnI → DnO** | `skeleton_created == true` AND `build_verified == true` |
| **DnO → completed** | `deployment_count > 0` AND `active_incidents == 0` |

**Revisiting:** Any active phase can revisit an earlier phase. The `REVISITING` flag is set, and the previous phase's `_ACTIVE` flag is restored. Gate counters are preserved.

---

## Sub-Process Summary

| Sub-Process | Desks | Events |
|-------------|--------|--------|
| Orchestration | 3 | `project_initiated_v1`, `phase_transitioned_v1`, `phase_revisited_v1` |
| **discovery_n_analysis** | 4 | `discovery_started_v1`, `finding_recorded_v1`, `term_defined_v1`, `discovery_completed_v1` |
| **architecture_n_planning** | 6 | `architecture_started_v1`, `dossier_defined_v1`, `desk_inventoried_v1`, `plan_drafted_v1`, `plan_approved_v1`, `architecture_completed_v1` |
| **testing_n_implementation** | 5 | `testing_started_v1`, `skeleton_scaffolded_v1`, `desk_implemented_v1`, `build_verified_v1`, `testing_completed_v1` |
| **deployment_n_operations** | 6 | `deployment_started_v1`, `release_deployed_v1`, `monitoring_configured_v1`, `incident_recorded_v1`, `incident_resolved_v1`, `operations_completed_v1` |
| **Total** | **24** | **25 event types** |

See [PLAN_ALC_CMD.md](PLAN_ALC_CMD.md) for full desk specifications.

---

## Implementation Phases

### Phase 1: Foundation + Orchestration + DnA

1. Create `apps/manage_alc/` structure (app.src, app.erl, sup.erl, rebar.config)
2. `alc_aggregate.erl` — initial_state + execute/apply_event for orchestration + DnA events
3. `initiate_project/` desk (command, event, handler)
4. `discovery_n_analysis/start_discovery/` desk
5. `discovery_n_analysis/record_finding/` desk
6. `discovery_n_analysis/define_term/` desk
7. `discovery_n_analysis/complete_discovery/` desk (with gate enforcement)
8. Create `apps/query_alc/` structure
9. `query_alc_store.erl` — SQLite with projects + findings + terms tables
10. `query_alc_subscriber.erl` — subscribe to manage_alc_store events
11. Projections for Phase 1 events
12. `list_projects`, `get_project`, `list_findings`, `list_terms` queries
13. `hecate_api_alc.erl` — Phase 1 endpoints
14. Infrastructure: routes, rebar.config, sys.config
15. **Verify:** `rebar3 compile` clean

### Phase 2: AnP Sub-Process

1. `architecture_n_planning/start_architecture/` desk
2. `architecture_n_planning/define_dossier/` desk
3. `architecture_n_planning/inventory_desk/` desk
4. `architecture_n_planning/draft_plan/` desk
5. `architecture_n_planning/approve_plan/` desk
6. `architecture_n_planning/complete_architecture/` desk (with gate enforcement)
7. Extend `alc_aggregate.erl` for AnP events
8. Add dossier_designs, desk_inventory, plans tables
9. Projections + queries for AnP
10. API endpoints for AnP
11. `transition_phase/` desk (DnA→AnP and AnP→TnI transitions)
12. **Verify:** `rebar3 compile` clean

### Phase 3: TnI Sub-Process

1. `testing_n_implementation/start_testing/` desk
2. `testing_n_implementation/scaffold_skeleton/` desk
3. `testing_n_implementation/implement_desk/` desk
4. `testing_n_implementation/verify_build/` desk
5. `testing_n_implementation/complete_testing/` desk (with gate enforcement)
6. Extend `alc_aggregate.erl` for TnI events
7. Add implementations table
8. Projections + queries for TnI
9. API endpoints for TnI
10. **Verify:** `rebar3 compile` clean

### Phase 4: DnO Sub-Process + Completion

1. `deployment_n_operations/start_deployment/` desk
2. `deployment_n_operations/deploy_release/` desk
3. `deployment_n_operations/configure_monitoring/` desk
4. `deployment_n_operations/record_incident/` desk
5. `deployment_n_operations/resolve_incident/` desk
6. `deployment_n_operations/complete_operations/` desk (with gate enforcement)
7. `revisit_phase/` desk
8. Extend `alc_aggregate.erl` for remaining events
9. Add deployments + incidents tables
10. All remaining projections + queries
11. All remaining API endpoints
12. **Verify:** `rebar3 compile` + `rebar3 dialyzer`

### Phase 5: TUI Integration

1. Client methods in hecate-tui (`internal/client/alc.go`)
2. Slash commands: `/project init`, `/phase`, `/discovery`, `/architecture`, `/testing`, `/deployment`
3. **Verify:** `go build`

---

## File Count Estimate

| Component | Files |
|-----------|-------|
| manage_alc (CMD) | ~75 (aggregate + 24 desks × 3 files each + sup/app/app.src/rebar) |
| query_alc (QRY) | ~40 (store + subscriber + ~25 projections + ~9 queries + sup/app/app.src/rebar) |
| hecate_api_alc | 1 |
| Infrastructure | ~3 (routes, rebar configs) |
| TUI (Go) | ~3 (client, commands, types) |
| **Total** | **~122 files** |

---

## Patterns to Follow

| Pattern | Reference |
|---------|-----------|
| Domain supervisor + ReckonDB store | `apps/mentor_agents/src/mentor_agents_sup.erl` |
| Aggregate with bit flags | `apps/mentor_agents/src/submit_learning/learning_aggregate.erl` |
| Command module | `apps/mentor_agents/src/submit_learning/submit_learning_v1.erl` |
| Event module | `apps/mentor_agents/src/submit_learning/learning_submitted_v1.erl` |
| Handler module | `apps/mentor_agents/src/submit_learning/maybe_submit_learning.erl` |
| SQLite query store | `apps/query_mentors/src/query_mentors_store.erl` |
| Event subscriber | `apps/query_mentors/src/query_mentors_subscriber.erl` |
| API handler | `apps/hecate_api/src/hecate_api_mentors.erl` |
| Routes | `apps/hecate_api/src/hecate_api_routes.erl` |

---

## Open Questions

1. Should completed ALC projects be archived (events compacted)?
2. Should the ALC publish to mesh? (e.g., `hecate.project.completed` for fleet-wide visibility)
3. Should phase gates be soft (warn) or hard (refuse)?
4. How does the TUI know which project is "active" for contextual commands?

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-05 | Single `manage_alc` domain, not 4 domains | Phases are sub-processes, not bounded contexts. 1 stream per project. |
| 2026-02-05 | Sub-processes as directories containing desks | Organizational grouping. Each directory has multiple desks. |
| 2026-02-05 | Aggregate tracks counters, not artifacts | Lean aggregate for gate enforcement. Details in read models. |
| 2026-02-05 | No mesh emitters initially | ALC is internal lifecycle tracking. Can add later. |
| 2026-02-05 | Phase names: `discovery_n_analysis`, `architecture_n_planning`, `testing_n_implementation`, `deployment_n_operations` | Avoids keyword conflicts (`and`, `int`). Discovery comes first, Testing comes first, etc. Screams intent. |
