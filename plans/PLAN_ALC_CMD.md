# PLAN: manage_alc — Command Service

**Parent:** [PLAN_ALC_ROOT.md](PLAN_ALC_ROOT.md)

---

## Store

- **Store ID:** `manage_alc_store`
- **Data dir:** `data/reckon/manage_alc`
- **Pattern:** `apps/mentor_agents/src/mentor_agents_sup.erl`

---

## Aggregate: `alc_aggregate`

**Shared across ALL spokes.** Lives at `apps/manage_alc/src/alc_aggregate.erl`.

### State Record

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

    %% DnA counters
    finding_count           :: non_neg_integer(),
    term_count              :: non_neg_integer(),

    %% AnP counters
    dossier_count           :: non_neg_integer(),
    spoke_count             :: non_neg_integer(),
    plan_approved           :: boolean(),

    %% TnI counters
    skeleton_created        :: boolean(),
    implemented_spoke_count :: non_neg_integer(),
    build_verified          :: boolean(),

    %% DnO counters
    deployment_count        :: non_neg_integer(),
    active_incidents        :: non_neg_integer(),

    %% Timestamps
    initiated_at            :: non_neg_integer() | undefined,
    phase_started_at        :: non_neg_integer() | undefined,
    completed_at            :: non_neg_integer() | undefined
}).
```

### Bit Flags

```erlang
-define(INITIATED,             1).
-define(DISCOVERY_ACTIVE,      2).
-define(DISCOVERY_COMPLETE,    4).
-define(ARCHITECTURE_ACTIVE,   8).
-define(ARCHITECTURE_COMPLETE,16).
-define(TESTING_ACTIVE,       32).
-define(TESTING_COMPLETE,     64).
-define(DEPLOYMENT_ACTIVE,   128).
-define(DEPLOYMENT_COMPLETE, 256).
-define(COMPLETED,           512).
-define(REVISITING,         1024).
```

### Execute Rules

The aggregate's `execute/2` enforces:

- **Phase activity:** Most spokes require their sub-process phase to be active
- **Phase gates:** Completion spokes check counter thresholds
- **Idempotency:** Duplicate events rejected (e.g., can't initiate twice)

### Apply Event Rules

`apply_event/2` updates counters, flags, and current_phase. Pure state transitions — no side effects.

---

## Orchestration Spokes (3)

These live directly under `src/` (not in a sub-process directory).

### 1. `initiate_project/`

**Stream:** `alc-{project_id}`

| Element | Value |
|---------|-------|
| Command | `initiate_project_v1` |
| Event | `project_initiated_v1` |
| Handler | `maybe_initiate_project` |

**Command fields:**
```erlang
-record(initiate_project_v1, {
    project_id  :: binary(),
    name        :: binary(),
    description :: binary() | undefined
}).
```

**Event fields:**
```erlang
-record(project_initiated_v1, {
    project_id   :: binary(),
    name         :: binary(),
    description  :: binary() | undefined,
    initiated_at :: non_neg_integer()
}).
```

**Execute guard:** `status == 0` (not yet initiated)

**Apply:** Sets `status |= INITIATED bor DISCOVERY_ACTIVE`, `current_phase = discovery_n_analysis`

---

### 2. `transition_phase/`

| Element | Value |
|---------|-------|
| Command | `transition_phase_v1` |
| Event | `phase_transitioned_v1` |
| Handler | `maybe_transition_phase` |

**Command fields:**
```erlang
-record(transition_phase_v1, {
    project_id :: binary(),
    from_phase :: discovery_n_analysis | architecture_n_planning
               | testing_n_implementation | deployment_n_operations,
    to_phase   :: architecture_n_planning | testing_n_implementation
               | deployment_n_operations | completed
}).
```

**Event fields:**
```erlang
-record(phase_transitioned_v1, {
    project_id      :: binary(),
    from_phase      :: atom(),
    to_phase        :: atom(),
    transitioned_at :: non_neg_integer()
}).
```

**Execute guard:** `current_phase == from_phase` AND gate conditions met for the transition (see PLAN_ALC_ROOT.md Phase Gates).

**Apply:** Clears `from_phase _ACTIVE`, sets `from_phase _COMPLETE bor to_phase _ACTIVE`, updates `current_phase`. When `to_phase = completed`, sets `status |= COMPLETED` and records `completed_at`.

---

### 3. `revisit_phase/`

| Element | Value |
|---------|-------|
| Command | `revisit_phase_v1` |
| Event | `phase_revisited_v1` |
| Handler | `maybe_revisit_phase` |

**Command fields:**
```erlang
-record(revisit_phase_v1, {
    project_id   :: binary(),
    target_phase :: discovery_n_analysis | architecture_n_planning
                 | testing_n_implementation | deployment_n_operations,
    reason       :: binary()
}).
```

**Event fields:**
```erlang
-record(phase_revisited_v1, {
    project_id   :: binary(),
    from_phase   :: atom(),
    target_phase :: atom(),
    reason       :: binary(),
    revisited_at :: non_neg_integer()
}).
```

**Execute guard:** `status band INITIATED /= 0` AND `target_phase` is earlier than or equal to `current_phase`. Cannot revisit if COMPLETED.

**Apply:** Sets `status |= REVISITING`, updates `current_phase = target_phase`, sets `target_phase _ACTIVE`. Does NOT clear counters.

---

## discovery_n_analysis Sub-Process (4 spokes)

Directory: `src/discovery_n_analysis/`

All DnA spokes require: `status band DISCOVERY_ACTIVE /= 0`

### 1. `discovery_n_analysis/start_discovery/`

| Element | Value |
|---------|-------|
| Command | `start_discovery_v1` |
| Event | `discovery_started_v1` |
| Handler | `maybe_start_discovery` |

**Command fields:**
```erlang
-record(start_discovery_v1, {
    project_id :: binary()
}).
```

**Event fields:**
```erlang
-record(discovery_started_v1, {
    project_id :: binary(),
    started_at :: non_neg_integer()
}).
```

**Execute guard:** `current_phase == discovery_n_analysis` AND discovery not already started.

**Apply:** Records `phase_started_at`.

**Note:** `initiate_project` already sets DnA active, so `start_discovery` is the explicit "I'm beginning discovery work" signal. Optional but recommended for tracking.

---

### 2. `discovery_n_analysis/record_finding/`

| Element | Value |
|---------|-------|
| Command | `record_finding_v1` |
| Event | `finding_recorded_v1` |
| Handler | `maybe_record_finding` |

**Command fields:**
```erlang
-record(record_finding_v1, {
    project_id :: binary(),
    finding_id :: binary(),
    category   :: binary(),     %% <<"requirement">> | <<"constraint">> | <<"risk">>
                                %% | <<"domain_concept">> | <<"prior_art">>
    title      :: binary(),
    content    :: binary() | undefined,
    priority   :: binary()      %% <<"must">> | <<"should">> | <<"could">> | <<"wont">>
}).
```

**Event fields:**
```erlang
-record(finding_recorded_v1, {
    project_id  :: binary(),
    finding_id  :: binary(),
    category    :: binary(),
    title       :: binary(),
    content     :: binary() | undefined,
    priority    :: binary(),
    recorded_at :: non_neg_integer()
}).
```

**Execute guard:** `current_phase == discovery_n_analysis`

**Apply:** `finding_count += 1`

---

### 3. `discovery_n_analysis/define_term/`

| Element | Value |
|---------|-------|
| Command | `define_term_v1` |
| Event | `term_defined_v1` |
| Handler | `maybe_define_term` |

**Command fields:**
```erlang
-record(define_term_v1, {
    project_id :: binary(),
    term_id    :: binary(),
    term       :: binary(),
    definition :: binary()
}).
```

**Event fields:**
```erlang
-record(term_defined_v1, {
    project_id :: binary(),
    term_id    :: binary(),
    term       :: binary(),
    definition :: binary(),
    defined_at :: non_neg_integer()
}).
```

**Execute guard:** `current_phase == discovery_n_analysis`

**Apply:** `term_count += 1`

---

### 4. `discovery_n_analysis/complete_discovery/`

| Element | Value |
|---------|-------|
| Command | `complete_discovery_v1` |
| Event | `discovery_completed_v1` |
| Handler | `maybe_complete_discovery` |

**Command fields:**
```erlang
-record(complete_discovery_v1, {
    project_id :: binary()
}).
```

**Event fields:**
```erlang
-record(discovery_completed_v1, {
    project_id   :: binary(),
    completed_at :: non_neg_integer()
}).
```

**Execute guard (GATE):** `current_phase == discovery_n_analysis` AND `finding_count > 0` AND `term_count > 0`

**Apply:** Sets `status |= DISCOVERY_COMPLETE`. Does NOT transition phase — use `transition_phase` for that.

---

## architecture_n_planning Sub-Process (6 spokes)

Directory: `src/architecture_n_planning/`

All AnP spokes require: `status band ARCHITECTURE_ACTIVE /= 0`

### 1. `architecture_n_planning/start_architecture/`

| Element | Value |
|---------|-------|
| Command | `start_architecture_v1` |
| Event | `architecture_started_v1` |
| Handler | `maybe_start_architecture` |

**Command:** `project_id :: binary()`

**Event:** `project_id`, `started_at`

**Execute guard:** `current_phase == architecture_n_planning`

**Apply:** Records `phase_started_at`.

---

### 2. `architecture_n_planning/define_dossier/`

| Element | Value |
|---------|-------|
| Command | `define_dossier_v1` |
| Event | `dossier_defined_v1` |
| Handler | `maybe_define_dossier` |

**Command fields:**
```erlang
-record(define_dossier_v1, {
    project_id     :: binary(),
    dossier_id     :: binary(),
    dossier_name   :: binary(),
    stream_pattern :: binary(),       %% e.g., <<"capability-{mri}">>
    description    :: binary() | undefined
}).
```

**Event fields:** Same + `defined_at`

**Execute guard:** `current_phase == architecture_n_planning`

**Apply:** `dossier_count += 1`

---

### 3. `architecture_n_planning/inventory_spoke/`

| Element | Value |
|---------|-------|
| Command | `inventory_spoke_v1` |
| Event | `spoke_inventoried_v1` |
| Handler | `maybe_inventory_spoke` |

**Command fields:**
```erlang
-record(inventory_spoke_v1, {
    project_id  :: binary(),
    spoke_id    :: binary(),
    spoke_name  :: binary(),
    spoke_type  :: binary(),          %% <<"cmd">> | <<"prj">> | <<"qry">> | <<"listener">> | <<"emitter">>
    priority    :: binary(),          %% <<"p0">> (skeleton) | <<"p1">> | <<"p2">> | <<"p3">>
    dossier_id  :: binary() | undefined,
    description :: binary() | undefined
}).
```

**Event fields:** Same + `inventoried_at`

**Execute guard:** `current_phase == architecture_n_planning`

**Apply:** `spoke_count += 1`

---

### 4. `architecture_n_planning/draft_plan/`

| Element | Value |
|---------|-------|
| Command | `draft_plan_v1` |
| Event | `plan_drafted_v1` |
| Handler | `maybe_draft_plan` |

**Command fields:**
```erlang
-record(draft_plan_v1, {
    project_id  :: binary(),
    plan_id     :: binary(),
    title       :: binary(),
    content_ref :: binary()           %% path or URL to PLAN document
}).
```

**Event fields:** Same + `drafted_at`

**Execute guard:** `current_phase == architecture_n_planning`

**Apply:** No counter change (plan existence tracked in read model).

---

### 5. `architecture_n_planning/approve_plan/`

| Element | Value |
|---------|-------|
| Command | `approve_plan_v1` |
| Event | `plan_approved_v1` |
| Handler | `maybe_approve_plan` |

**Command fields:**
```erlang
-record(approve_plan_v1, {
    project_id :: binary(),
    plan_id    :: binary()
}).
```

**Event fields:** Same + `approved_at`

**Execute guard:** `current_phase == architecture_n_planning` AND `plan_approved == false`

**Apply:** `plan_approved = true`

---

### 6. `architecture_n_planning/complete_architecture/`

| Element | Value |
|---------|-------|
| Command | `complete_architecture_v1` |
| Event | `architecture_completed_v1` |
| Handler | `maybe_complete_architecture` |

**Command:** `project_id :: binary()`

**Event:** `project_id`, `completed_at`

**Execute guard (GATE):** `current_phase == architecture_n_planning` AND `dossier_count > 0` AND `spoke_count > 0` AND `plan_approved == true`

**Apply:** Sets `status |= ARCHITECTURE_COMPLETE`.

---

## testing_n_implementation Sub-Process (5 spokes)

Directory: `src/testing_n_implementation/`

All TnI spokes require: `status band TESTING_ACTIVE /= 0`

### 1. `testing_n_implementation/start_testing/`

| Element | Value |
|---------|-------|
| Command | `start_testing_v1` |
| Event | `testing_started_v1` |
| Handler | `maybe_start_testing` |

**Command:** `project_id :: binary()`

**Event:** `project_id`, `started_at`

**Apply:** Records `phase_started_at`.

---

### 2. `testing_n_implementation/scaffold_skeleton/`

| Element | Value |
|---------|-------|
| Command | `scaffold_skeleton_v1` |
| Event | `skeleton_scaffolded_v1` |
| Handler | `maybe_scaffold_skeleton` |

**Command fields:**
```erlang
-record(scaffold_skeleton_v1, {
    project_id :: binary(),
    commit_ref :: binary() | undefined,
    notes      :: binary() | undefined
}).
```

**Event fields:** Same + `scaffolded_at`

**Execute guard:** `current_phase == testing_n_implementation` AND `skeleton_created == false`

**Apply:** `skeleton_created = true`

---

### 3. `testing_n_implementation/implement_spoke/`

| Element | Value |
|---------|-------|
| Command | `implement_spoke_v1` |
| Event | `spoke_implemented_v1` |
| Handler | `maybe_implement_spoke` |

**Command fields:**
```erlang
-record(implement_spoke_v1, {
    project_id        :: binary(),
    implementation_id :: binary(),
    spoke_name        :: binary(),
    spoke_id          :: binary() | undefined,   %% references AnP spoke_inventory
    commit_ref        :: binary() | undefined
}).
```

**Event fields:** Same + `implemented_at`

**Execute guard:** `current_phase == testing_n_implementation`

**Apply:** `implemented_spoke_count += 1`

---

### 4. `testing_n_implementation/verify_build/`

| Element | Value |
|---------|-------|
| Command | `verify_build_v1` |
| Event | `build_verified_v1` |
| Handler | `maybe_verify_build` |

**Command fields:**
```erlang
-record(verify_build_v1, {
    project_id   :: binary(),
    verification :: binary(),        %% <<"compile">> | <<"dialyzer">> | <<"eunit">> | <<"full">>
    result       :: binary(),        %% <<"pass">> | <<"fail">>
    notes        :: binary() | undefined
}).
```

**Event fields:** Same + `verified_at`

**Execute guard:** `current_phase == testing_n_implementation`

**Apply:** If `result == <<"pass">>` and `verification` is `<<"full">>` or `<<"eunit">>`, set `build_verified = true`.

---

### 5. `testing_n_implementation/complete_testing/`

| Element | Value |
|---------|-------|
| Command | `complete_testing_v1` |
| Event | `testing_completed_v1` |
| Handler | `maybe_complete_testing` |

**Command:** `project_id :: binary()`

**Event:** `project_id`, `completed_at`

**Execute guard (GATE):** `current_phase == testing_n_implementation` AND `skeleton_created == true` AND `build_verified == true`

**Apply:** Sets `status |= TESTING_COMPLETE`.

---

## deployment_n_operations Sub-Process (6 spokes)

Directory: `src/deployment_n_operations/`

All DnO spokes require: `status band DEPLOYMENT_ACTIVE /= 0`

### 1. `deployment_n_operations/start_deployment/`

| Element | Value |
|---------|-------|
| Command | `start_deployment_v1` |
| Event | `deployment_started_v1` |
| Handler | `maybe_start_deployment` |

**Command:** `project_id :: binary()`

**Event:** `project_id`, `started_at`

**Apply:** Records `phase_started_at`.

---

### 2. `deployment_n_operations/deploy_release/`

| Element | Value |
|---------|-------|
| Command | `deploy_release_v1` |
| Event | `release_deployed_v1` |
| Handler | `maybe_deploy_release` |

**Command fields:**
```erlang
-record(deploy_release_v1, {
    project_id    :: binary(),
    deployment_id :: binary(),
    environment   :: binary(),         %% <<"test">> | <<"staging">> | <<"prod">>
    version       :: binary(),
    notes         :: binary() | undefined
}).
```

**Event fields:** Same + `deployed_at`

**Execute guard:** `current_phase == deployment_n_operations`

**Apply:** `deployment_count += 1`

---

### 3. `deployment_n_operations/configure_monitoring/`

| Element | Value |
|---------|-------|
| Command | `configure_monitoring_v1` |
| Event | `monitoring_configured_v1` |
| Handler | `maybe_configure_monitoring` |

**Command fields:**
```erlang
-record(configure_monitoring_v1, {
    project_id :: binary(),
    scope      :: binary(),           %% <<"alerts">> | <<"dashboards">> | <<"logs">> | <<"full">>
    notes      :: binary() | undefined
}).
```

**Event fields:** Same + `configured_at`

**Execute guard:** `current_phase == deployment_n_operations`

**Apply:** No counter change (informational).

---

### 4. `deployment_n_operations/record_incident/`

| Element | Value |
|---------|-------|
| Command | `record_incident_v1` |
| Event | `incident_recorded_v1` |
| Handler | `maybe_record_incident` |

**Command fields:**
```erlang
-record(record_incident_v1, {
    project_id  :: binary(),
    incident_id :: binary(),
    severity    :: binary(),          %% <<"sev1">> | <<"sev2">> | <<"sev3">> | <<"sev4">>
    title       :: binary(),
    description :: binary() | undefined
}).
```

**Event fields:** Same + `recorded_at`

**Execute guard:** `current_phase == deployment_n_operations`

**Apply:** `active_incidents += 1`

---

### 5. `deployment_n_operations/resolve_incident/`

| Element | Value |
|---------|-------|
| Command | `resolve_incident_v1` |
| Event | `incident_resolved_v1` |
| Handler | `maybe_resolve_incident` |

**Command fields:**
```erlang
-record(resolve_incident_v1, {
    project_id  :: binary(),
    incident_id :: binary(),
    resolution  :: binary()
}).
```

**Event fields:** Same + `resolved_at`

**Execute guard:** `current_phase == deployment_n_operations` AND `active_incidents > 0`

**Apply:** `active_incidents -= 1`

---

### 6. `deployment_n_operations/complete_operations/`

| Element | Value |
|---------|-------|
| Command | `complete_operations_v1` |
| Event | `operations_completed_v1` |
| Handler | `maybe_complete_operations` |

**Command:** `project_id :: binary()`

**Event:** `project_id`, `completed_at`

**Execute guard (GATE):** `current_phase == deployment_n_operations` AND `deployment_count > 0` AND `active_incidents == 0`

**Apply:** Sets `status |= DEPLOYMENT_COMPLETE`.

---

## File Structure

```
apps/manage_alc/
├── rebar.config
├── src/
│   ├── manage_alc.app.src
│   ├── manage_alc_app.erl
│   ├── manage_alc_sup.erl
│   ├── alc_aggregate.erl
│   │
│   ├── initiate_project/
│   │   ├── initiate_project_v1.erl
│   │   ├── project_initiated_v1.erl
│   │   └── maybe_initiate_project.erl
│   │
│   ├── transition_phase/
│   │   ├── transition_phase_v1.erl
│   │   ├── phase_transitioned_v1.erl
│   │   └── maybe_transition_phase.erl
│   │
│   ├── revisit_phase/
│   │   ├── revisit_phase_v1.erl
│   │   ├── phase_revisited_v1.erl
│   │   └── maybe_revisit_phase.erl
│   │
│   ├── discovery_n_analysis/
│   │   ├── start_discovery/
│   │   │   ├── start_discovery_v1.erl
│   │   │   ├── discovery_started_v1.erl
│   │   │   └── maybe_start_discovery.erl
│   │   │
│   │   ├── record_finding/
│   │   │   ├── record_finding_v1.erl
│   │   │   ├── finding_recorded_v1.erl
│   │   │   └── maybe_record_finding.erl
│   │   │
│   │   ├── define_term/
│   │   │   ├── define_term_v1.erl
│   │   │   ├── term_defined_v1.erl
│   │   │   └── maybe_define_term.erl
│   │   │
│   │   └── complete_discovery/
│   │       ├── complete_discovery_v1.erl
│   │       ├── discovery_completed_v1.erl
│   │       └── maybe_complete_discovery.erl
│   │
│   ├── architecture_n_planning/
│   │   ├── start_architecture/
│   │   │   ├── start_architecture_v1.erl
│   │   │   ├── architecture_started_v1.erl
│   │   │   └── maybe_start_architecture.erl
│   │   │
│   │   ├── define_dossier/
│   │   │   ├── define_dossier_v1.erl
│   │   │   ├── dossier_defined_v1.erl
│   │   │   └── maybe_define_dossier.erl
│   │   │
│   │   ├── inventory_spoke/
│   │   │   ├── inventory_spoke_v1.erl
│   │   │   ├── spoke_inventoried_v1.erl
│   │   │   └── maybe_inventory_spoke.erl
│   │   │
│   │   ├── draft_plan/
│   │   │   ├── draft_plan_v1.erl
│   │   │   ├── plan_drafted_v1.erl
│   │   │   └── maybe_draft_plan.erl
│   │   │
│   │   ├── approve_plan/
│   │   │   ├── approve_plan_v1.erl
│   │   │   ├── plan_approved_v1.erl
│   │   │   └── maybe_approve_plan.erl
│   │   │
│   │   └── complete_architecture/
│   │       ├── complete_architecture_v1.erl
│   │       ├── architecture_completed_v1.erl
│   │       └── maybe_complete_architecture.erl
│   │
│   ├── testing_n_implementation/
│   │   ├── start_testing/
│   │   │   ├── start_testing_v1.erl
│   │   │   ├── testing_started_v1.erl
│   │   │   └── maybe_start_testing.erl
│   │   │
│   │   ├── scaffold_skeleton/
│   │   │   ├── scaffold_skeleton_v1.erl
│   │   │   ├── skeleton_scaffolded_v1.erl
│   │   │   └── maybe_scaffold_skeleton.erl
│   │   │
│   │   ├── implement_spoke/
│   │   │   ├── implement_spoke_v1.erl
│   │   │   ├── spoke_implemented_v1.erl
│   │   │   └── maybe_implement_spoke.erl
│   │   │
│   │   ├── verify_build/
│   │   │   ├── verify_build_v1.erl
│   │   │   ├── build_verified_v1.erl
│   │   │   └── maybe_verify_build.erl
│   │   │
│   │   └── complete_testing/
│   │       ├── complete_testing_v1.erl
│   │       ├── testing_completed_v1.erl
│   │       └── maybe_complete_testing.erl
│   │
│   └── deployment_n_operations/
│       ├── start_deployment/
│       │   ├── start_deployment_v1.erl
│       │   ├── deployment_started_v1.erl
│       │   └── maybe_start_deployment.erl
│       │
│       ├── deploy_release/
│       │   ├── deploy_release_v1.erl
│       │   ├── release_deployed_v1.erl
│       │   └── maybe_deploy_release.erl
│       │
│       ├── configure_monitoring/
│       │   ├── configure_monitoring_v1.erl
│       │   ├── monitoring_configured_v1.erl
│       │   └── maybe_configure_monitoring.erl
│       │
│       ├── record_incident/
│       │   ├── record_incident_v1.erl
│       │   ├── incident_recorded_v1.erl
│       │   └── maybe_record_incident.erl
│       │
│       ├── resolve_incident/
│       │   ├── resolve_incident_v1.erl
│       │   ├── incident_resolved_v1.erl
│       │   └── maybe_resolve_incident.erl
│       │
│       └── complete_operations/
│           ├── complete_operations_v1.erl
│           ├── operations_completed_v1.erl
│           └── maybe_complete_operations.erl
```

---

## rebar.config

```erlang
{erl_opts, [debug_info]}.
{deps, []}.
{src_dirs, [
    "src",
    "src/initiate_project",
    "src/transition_phase",
    "src/revisit_phase",
    "src/discovery_n_analysis/start_discovery",
    "src/discovery_n_analysis/record_finding",
    "src/discovery_n_analysis/define_term",
    "src/discovery_n_analysis/complete_discovery",
    "src/architecture_n_planning/start_architecture",
    "src/architecture_n_planning/define_dossier",
    "src/architecture_n_planning/inventory_spoke",
    "src/architecture_n_planning/draft_plan",
    "src/architecture_n_planning/approve_plan",
    "src/architecture_n_planning/complete_architecture",
    "src/testing_n_implementation/start_testing",
    "src/testing_n_implementation/scaffold_skeleton",
    "src/testing_n_implementation/implement_spoke",
    "src/testing_n_implementation/verify_build",
    "src/testing_n_implementation/complete_testing",
    "src/deployment_n_operations/start_deployment",
    "src/deployment_n_operations/deploy_release",
    "src/deployment_n_operations/configure_monitoring",
    "src/deployment_n_operations/record_incident",
    "src/deployment_n_operations/resolve_incident",
    "src/deployment_n_operations/complete_operations"
]}.
```

---

## Supervisor

`manage_alc_sup` starts:
1. ReckonDB store (`manage_alc_store`)
2. No emitters (ALC is internal)

Minimal supervisor — the domain's only infrastructure is the event store.
