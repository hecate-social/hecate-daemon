# PLAN: query_alc — Query Service + API + TUI

**Parent:** [PLAN_ALC_ROOT.md](PLAN_ALC_ROOT.md)

---

## SQLite Tables

### projects

```sql
CREATE TABLE IF NOT EXISTS projects (
    project_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    current_phase TEXT DEFAULT 'discovery_n_analysis',
    status INTEGER DEFAULT 1,
    finding_count INTEGER DEFAULT 0,
    term_count INTEGER DEFAULT 0,
    dossier_count INTEGER DEFAULT 0,
    desk_count INTEGER DEFAULT 0,
    plan_approved INTEGER DEFAULT 0,
    skeleton_created INTEGER DEFAULT 0,
    implemented_desk_count INTEGER DEFAULT 0,
    build_verified INTEGER DEFAULT 0,
    deployment_count INTEGER DEFAULT 0,
    active_incidents INTEGER DEFAULT 0,
    initiated_at INTEGER,
    phase_started_at INTEGER,
    completed_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_projects_phase ON projects(current_phase);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
```

### findings

```sql
CREATE TABLE IF NOT EXISTS findings (
    finding_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT,
    priority TEXT DEFAULT 'should',
    recorded_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_findings_project ON findings(project_id);
CREATE INDEX IF NOT EXISTS idx_findings_category ON findings(category);
```

### terms

```sql
CREATE TABLE IF NOT EXISTS terms (
    term_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    term TEXT NOT NULL,
    definition TEXT NOT NULL,
    defined_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_terms_project ON terms(project_id);
```

### dossier_designs

```sql
CREATE TABLE IF NOT EXISTS dossier_designs (
    dossier_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    dossier_name TEXT NOT NULL,
    stream_pattern TEXT,
    description TEXT,
    defined_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_dossiers_project ON dossier_designs(project_id);
```

### desk_inventory

```sql
CREATE TABLE IF NOT EXISTS desk_inventory (
    desk_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    desk_name TEXT NOT NULL,
    desk_type TEXT NOT NULL,
    priority TEXT DEFAULT 'p1',
    dossier_id TEXT,
    description TEXT,
    inventoried_at INTEGER,
    implemented INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_desks_project ON desk_inventory(project_id);
CREATE INDEX IF NOT EXISTS idx_desks_type ON desk_inventory(desk_type);
```

### plans

```sql
CREATE TABLE IF NOT EXISTS plans (
    plan_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    title TEXT NOT NULL,
    content_ref TEXT,
    approved INTEGER DEFAULT 0,
    drafted_at INTEGER,
    approved_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_plans_project ON plans(project_id);
```

### implementations

```sql
CREATE TABLE IF NOT EXISTS implementations (
    implementation_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    desk_id TEXT,
    desk_name TEXT NOT NULL,
    commit_ref TEXT,
    implemented_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_implementations_project ON implementations(project_id);
```

### deployments

```sql
CREATE TABLE IF NOT EXISTS deployments (
    deployment_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    environment TEXT NOT NULL,
    version TEXT NOT NULL,
    notes TEXT,
    deployed_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_deployments_project ON deployments(project_id);
CREATE INDEX IF NOT EXISTS idx_deployments_env ON deployments(environment);
```

### incidents

```sql
CREATE TABLE IF NOT EXISTS incidents (
    incident_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    severity TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    status INTEGER DEFAULT 1,
    resolution TEXT,
    recorded_at INTEGER,
    resolved_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_incidents_project ON incidents(project_id);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents(status);
```

**9 tables total.**

---

## Projections (25)

All projections subscribe to `manage_alc_store` events via `query_alc_subscriber`.

### Orchestration projections

| Projection | Source Event | Target Table | Action |
|-----------|-------------|--------------|--------|
| `project_initiated_v1_to_projects` | `project_initiated_v1` | projects | INSERT |
| `phase_transitioned_v1_to_projects` | `phase_transitioned_v1` | projects | UPDATE current_phase, status |
| `phase_revisited_v1_to_projects` | `phase_revisited_v1` | projects | UPDATE current_phase, status |

### DnA projections

| Projection | Source Event | Target Table | Action |
|-----------|-------------|--------------|--------|
| `discovery_started_v1_to_projects` | `discovery_started_v1` | projects | UPDATE phase_started_at |
| `finding_recorded_v1_to_findings` | `finding_recorded_v1` | findings | INSERT; UPDATE projects finding_count |
| `term_defined_v1_to_terms` | `term_defined_v1` | terms | INSERT; UPDATE projects term_count |
| `discovery_completed_v1_to_projects` | `discovery_completed_v1` | projects | UPDATE status |

### AnP projections

| Projection | Source Event | Target Table | Action |
|-----------|-------------|--------------|--------|
| `architecture_started_v1_to_projects` | `architecture_started_v1` | projects | UPDATE phase_started_at |
| `dossier_defined_v1_to_dossiers` | `dossier_defined_v1` | dossier_designs | INSERT; UPDATE projects dossier_count |
| `desk_inventoried_v1_to_spokes` | `desk_inventoried_v1` | desk_inventory | INSERT; UPDATE projects desk_count |
| `plan_drafted_v1_to_plans` | `plan_drafted_v1` | plans | INSERT |
| `plan_approved_v1_to_plans` | `plan_approved_v1` | plans | UPDATE approved; UPDATE projects plan_approved |
| `architecture_completed_v1_to_projects` | `architecture_completed_v1` | projects | UPDATE status |

### TnI projections

| Projection | Source Event | Target Table | Action |
|-----------|-------------|--------------|--------|
| `testing_started_v1_to_projects` | `testing_started_v1` | projects | UPDATE phase_started_at |
| `skeleton_scaffolded_v1_to_projects` | `skeleton_scaffolded_v1` | projects | UPDATE skeleton_created |
| `desk_implemented_v1_to_implementations` | `desk_implemented_v1` | implementations | INSERT; UPDATE projects implemented_desk_count; UPDATE desk_inventory implemented |
| `build_verified_v1_to_projects` | `build_verified_v1` | projects | UPDATE build_verified |
| `testing_completed_v1_to_projects` | `testing_completed_v1` | projects | UPDATE status |

### DnO projections

| Projection | Source Event | Target Table | Action |
|-----------|-------------|--------------|--------|
| `deployment_started_v1_to_projects` | `deployment_started_v1` | projects | UPDATE phase_started_at |
| `release_deployed_v1_to_deployments` | `release_deployed_v1` | deployments | INSERT; UPDATE projects deployment_count |
| `monitoring_configured_v1_to_projects` | `monitoring_configured_v1` | projects | (informational — no counter) |
| `incident_recorded_v1_to_incidents` | `incident_recorded_v1` | incidents | INSERT; UPDATE projects active_incidents |
| `incident_resolved_v1_to_incidents` | `incident_resolved_v1` | incidents | UPDATE status, resolution; UPDATE projects active_incidents |
| `operations_completed_v1_to_projects` | `operations_completed_v1` | projects | UPDATE status |

---

## Queries (9)

### `list_projects/`

```sql
SELECT * FROM projects
  WHERE status & ? != 0
  ORDER BY initiated_at DESC
  LIMIT ?
```

Parameters: `status_mask` (default: all), `limit` (default: 50)

### `get_project/`

```sql
SELECT * FROM projects WHERE project_id = ?
```

Parameters: `project_id`

### `list_findings/`

```sql
SELECT * FROM findings
  WHERE project_id = ?
  ORDER BY recorded_at DESC
```

Optional filters: `category`, `priority`

### `list_terms/`

```sql
SELECT * FROM terms
  WHERE project_id = ?
  ORDER BY term ASC
```

### `list_dossier_designs/`

```sql
SELECT * FROM dossier_designs
  WHERE project_id = ?
  ORDER BY defined_at ASC
```

### `list_desk_inventory/`

```sql
SELECT * FROM desk_inventory
  WHERE project_id = ?
  ORDER BY priority ASC, inventoried_at ASC
```

Optional filters: `desk_type`, `implemented` (0 or 1)

### `list_implementations/`

```sql
SELECT * FROM implementations
  WHERE project_id = ?
  ORDER BY implemented_at DESC
```

### `list_deployments/`

```sql
SELECT * FROM deployments
  WHERE project_id = ?
  ORDER BY deployed_at DESC
```

Optional filters: `environment`

### `list_incidents/`

```sql
SELECT * FROM incidents
  WHERE project_id = ?
  ORDER BY recorded_at DESC
```

Optional filters: `status` (open=1, resolved=4), `severity`

---

## API Endpoints

**Handler:** `apps/hecate_api/src/hecate_api_alc.erl`

### Orchestration

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| POST | `/alc/projects` | initiate | Initiate a new ALC project |
| GET | `/alc/projects` | list_projects | List all projects |
| GET | `/alc/projects/:project_id` | get_project | Get project details |
| POST | `/alc/projects/:project_id/transition` | transition | Transition to next phase |
| POST | `/alc/projects/:project_id/revisit` | revisit | Revisit an earlier phase |

### DnA (Discovery & Analysis)

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| POST | `/alc/projects/:project_id/discovery/start` | discovery_start | Start discovery |
| POST | `/alc/projects/:project_id/discovery/findings` | discovery_finding | Record a finding |
| GET | `/alc/projects/:project_id/discovery/findings` | discovery_list_findings | List findings |
| POST | `/alc/projects/:project_id/discovery/terms` | discovery_term | Define a term |
| GET | `/alc/projects/:project_id/discovery/terms` | discovery_list_terms | List terms |
| POST | `/alc/projects/:project_id/discovery/complete` | discovery_complete | Complete discovery |

### AnP (Architecture & Planning)

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| POST | `/alc/projects/:project_id/architecture/start` | architecture_start | Start architecture |
| POST | `/alc/projects/:project_id/architecture/dossiers` | architecture_dossier | Define a dossier |
| GET | `/alc/projects/:project_id/architecture/dossiers` | architecture_list_dossiers | List dossier designs |
| POST | `/alc/projects/:project_id/architecture/desks` | architecture_desk | Inventory a desk |
| GET | `/alc/projects/:project_id/architecture/desks` | architecture_list_desks | List desk inventory |
| POST | `/alc/projects/:project_id/architecture/plan` | architecture_plan | Draft a plan |
| POST | `/alc/projects/:project_id/architecture/approve` | architecture_approve | Approve plan |
| POST | `/alc/projects/:project_id/architecture/complete` | architecture_complete | Complete architecture |

### TnI (Testing & Implementation)

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| POST | `/alc/projects/:project_id/testing/start` | testing_start | Start testing |
| POST | `/alc/projects/:project_id/testing/skeleton` | testing_skeleton | Record skeleton creation |
| POST | `/alc/projects/:project_id/testing/implement` | testing_implement | Record desk implementation |
| GET | `/alc/projects/:project_id/testing/implementations` | testing_list | List implementations |
| POST | `/alc/projects/:project_id/testing/verify` | testing_verify | Record build verification |
| POST | `/alc/projects/:project_id/testing/complete` | testing_complete | Complete testing |

### DnO (Deployment & Operations)

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| POST | `/alc/projects/:project_id/deployment/start` | deployment_start | Start deployment |
| POST | `/alc/projects/:project_id/deployment/deploy` | deployment_deploy | Record deployment |
| GET | `/alc/projects/:project_id/deployment/deployments` | deployment_list_deployments | List deployments |
| POST | `/alc/projects/:project_id/deployment/monitor` | deployment_monitor | Record monitoring configured |
| POST | `/alc/projects/:project_id/deployment/incident` | deployment_incident | Record incident |
| POST | `/alc/projects/:project_id/deployment/resolve/:incident_id` | deployment_resolve | Resolve incident |
| GET | `/alc/projects/:project_id/deployment/incidents` | deployment_list_incidents | List incidents |
| POST | `/alc/projects/:project_id/deployment/complete` | deployment_complete | Complete operations |

**34 endpoints total.**

---

## TUI Slash Commands

Commands for `hecate-tui` to integrate with the ALC daemon API.

### Project Management

| Command | Description | API Call |
|---------|-------------|----------|
| `/project init <name>` | Initiate new ALC project | POST `/alc/projects` |
| `/project list` | List all projects | GET `/alc/projects` |
| `/project <id>` | Show project details + phase status | GET `/alc/projects/:id` |
| `/phase` | Show current phase for active project | GET `/alc/projects/:id` (display phase) |
| `/phase next` | Transition to next phase | POST `/alc/projects/:id/transition` |
| `/phase revisit <phase>` | Revisit earlier phase | POST `/alc/projects/:id/revisit` |

### Discovery Commands (contextual — only when in DnA phase)

| Command | Description |
|---------|-------------|
| `/discovery start` | Start discovery phase |
| `/discovery finding <title>` | Record a finding (prompts for category, content, priority) |
| `/discovery term <term> <definition>` | Define a domain term |
| `/discovery complete` | Complete discovery (checks gate) |
| `/discovery findings` | List findings for current project |
| `/discovery terms` | List terms for current project |

### Architecture Commands (contextual — only when in AnP phase)

| Command | Description |
|---------|-------------|
| `/architecture start` | Start architecture phase |
| `/architecture dossier <name>` | Define a dossier (prompts for stream_pattern, description) |
| `/architecture desk <name>` | Inventory a desk (prompts for type, priority, dossier) |
| `/architecture plan <ref>` | Draft plan reference |
| `/architecture approve` | Approve the plan |
| `/architecture complete` | Complete architecture (checks gate) |
| `/architecture dossiers` | List dossier designs |
| `/architecture desks` | List desk inventory |

### Testing Commands (contextual — only when in TnI phase)

| Command | Description |
|---------|-------------|
| `/testing start` | Start testing phase |
| `/testing skeleton` | Record walking skeleton creation |
| `/testing desk <name>` | Record desk implementation (prompts for commit_ref) |
| `/testing verify` | Record build verification |
| `/testing complete` | Complete testing (checks gate) |
| `/testing list` | List implementations |

### Deployment Commands (contextual — only when in DnO phase)

| Command | Description |
|---------|-------------|
| `/deployment start` | Start deployment phase |
| `/deployment deploy <env> <version>` | Record deployment |
| `/deployment monitor` | Record monitoring configured |
| `/deployment incident <title>` | Record incident (prompts for severity, description) |
| `/deployment resolve <incident_id>` | Resolve incident |
| `/deployment complete` | Complete operations (checks gate) |
| `/deployment deployments` | List deployments |
| `/deployment incidents` | List incidents |

### Active Project Context

The TUI tracks an **active project** (stored in config or session state). Phase-specific commands operate on the active project automatically:

```
/project init weather-service         → sets active project
/discovery finding "Need QUIC support" → records finding for weather-service
/phase next                            → transitions weather-service DnA→AnP
```

Switch active project: `/project <id>` sets it.

---

## File Structure

```
apps/query_alc/
├── rebar.config
├── src/
│   ├── query_alc.app.src
│   ├── query_alc_app.erl
│   ├── query_alc_sup.erl
│   ├── query_alc_store.erl
│   ├── query_alc_subscriber.erl
│   │
│   ├── project_initiated_v1_to_projects.erl
│   ├── phase_transitioned_v1_to_projects.erl
│   ├── phase_revisited_v1_to_projects.erl
│   ├── discovery_started_v1_to_projects.erl
│   ├── finding_recorded_v1_to_findings.erl
│   ├── term_defined_v1_to_terms.erl
│   ├── discovery_completed_v1_to_projects.erl
│   ├── architecture_started_v1_to_projects.erl
│   ├── dossier_defined_v1_to_dossiers.erl
│   ├── desk_inventoried_v1_to_spokes.erl
│   ├── plan_drafted_v1_to_plans.erl
│   ├── plan_approved_v1_to_plans.erl
│   ├── architecture_completed_v1_to_projects.erl
│   ├── testing_started_v1_to_projects.erl
│   ├── skeleton_scaffolded_v1_to_projects.erl
│   ├── desk_implemented_v1_to_implementations.erl
│   ├── build_verified_v1_to_projects.erl
│   ├── testing_completed_v1_to_projects.erl
│   ├── deployment_started_v1_to_projects.erl
│   ├── release_deployed_v1_to_deployments.erl
│   ├── monitoring_configured_v1_to_projects.erl
│   ├── incident_recorded_v1_to_incidents.erl
│   ├── incident_resolved_v1_to_incidents.erl
│   ├── operations_completed_v1_to_projects.erl
│   │
│   ├── list_projects/
│   │   └── list_projects.erl
│   ├── get_project/
│   │   └── get_project.erl
│   ├── list_findings/
│   │   └── list_findings.erl
│   ├── list_terms/
│   │   └── list_terms.erl
│   ├── list_dossier_designs/
│   │   └── list_dossier_designs.erl
│   ├── list_desk_inventory/
│   │   └── list_desk_inventory.erl
│   ├── list_implementations/
│   │   └── list_implementations.erl
│   ├── list_deployments/
│   │   └── list_deployments.erl
│   └── list_incidents/
│       └── list_incidents.erl
```

### rebar.config

```erlang
{erl_opts, [debug_info]}.
{deps, [
    {manage_alc, {path, "../manage_alc"}}
]}.
{src_dirs, [
    "src",
    "src/list_projects",
    "src/get_project",
    "src/list_findings",
    "src/list_terms",
    "src/list_dossier_designs",
    "src/list_desk_inventory",
    "src/list_implementations",
    "src/list_deployments",
    "src/list_incidents"
]}.
```

---

## Infrastructure Changes

### Root rebar.config

Add to release apps:

```erlang
%% After manage_connectors, mentor_agents
manage_alc,           %% Application Lifecycle (CMD)

%% After query_mentors
query_alc,            %% ALC read models (QRY)
```

### hecate_api rebar.config

Add dependencies:

```erlang
{manage_alc, {path, "../manage_alc"}},
{query_alc, {path, "../query_alc"}}
```

### hecate_api.app.src

Add `manage_alc`, `query_alc` to applications list.

### hecate_api_routes.erl

Add `alc_routes/0` function returning all 34 routes.

### config/sys.config

```erlang
{manage_alc, [
    {enabled, true}
]},
```

---

## hecate-corpus Updates Required

The phase rename from `AnD/AnP/InT/DoO` to `discovery_n_analysis/architecture_n_planning/testing_n_implementation/deployment_n_operations` requires updating the following files in `hecate-social/hecate-corpus/`:

| File | Changes |
|------|---------|
| `philosophy/HECATE_ALC.md` | Phase names, diagram, abbreviations |
| `philosophy/HECATE_AnD.md` | Rename to `HECATE_DISCOVERY_N_ANALYSIS.md` |
| `philosophy/HECATE_AnP.md` | Rename to `HECATE_ARCHITECTURE_N_PLANNING.md` |
| `philosophy/HECATE_InT.md` | Rename to `HECATE_TESTING_N_IMPLEMENTATION.md` |
| `philosophy/HECATE_DoO.md` | Rename to `HECATE_DEPLOYMENT_N_OPERATIONS.md` |
| `philosophy/HECATE_WALKING_SKELETON.md` | References to InT → TnI |
| Any SVGs referencing phase names | Update labels |
