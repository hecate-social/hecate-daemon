# Vision: Hecate Ecosystem

## Status: DRAFT (2026-02-08)

This document captures the comprehensive mental model for the Hecate ecosystem, developed through deep discussion.

---

## Executive Summary

Hecate is a **goddess-themed AI agent platform** where one human works with multiple AI agents (the "Hecate swarm") to develop software. Built on the Macula mesh network with Erlang's actor model at its core.

**Core Insight:** Teams are evolving from "humans collaborating" to "one human + N AI agents". Hecate embraces this fully.

---

## The Name: Hecate

**Hecate** (Ἑκάτη) is the Greek goddess of:
- **Crossroads** - guiding decisions at critical junctures
- **Magic** - transformation and the arcane
- **The Moon** - illumination in darkness
- **Keys** - access to hidden knowledge
- **Three Bodies** (Triformis) - multiplicity, seeing in all directions

The multi-agent model reflects Hecate's three-bodied nature.

---

## Core Concepts

### 1. Venture

**A Venture is a business endeavor you're illuminating** - manifesting across multiple repositories.

Not "a collection of repos" but "the thing I'm building" - represented as a dedicated repository that acts as the project's brain.

```
~/work/github.com/hecate-social/macula-platform/    # THE VENTURE
├── VISION.md                 # Why does this exist?
├── CONTEXT_MAP.md            # Big picture
├── venture.toml              # Repo references, config
├── tasks/                    # Task artifacts (by ALC phase)
├── decisions/                # ADRs
└── diagrams/                 # Architecture SVGs
```

The Venture repo references code repos:

```toml
# venture.toml
[venture]
name = "macula-platform"
description = "Macula mesh + Hecate AI development environment"

[repos]
"macula-io/macula" = { role = "core", detection = "aggressive" }
"macula-io/macula-boot" = { role = "infrastructure" }
"hecate-social/hecate-daemon" = { role = "core" }
"hecate-social/hecate-tui" = { role = "client" }
"reckon-db-org/evoq" = { role = "library" }
```

### 2. Workspace Structure

Opinionated directory layout:

```
~/work/
├── github.com/
│   ├── hecate-social/
│   │   ├── macula-platform/     # Venture repo
│   │   ├── hecate-daemon/       # Code repo
│   │   └── hecate-tui/          # Code repo
│   └── macula-io/
│       └── macula/              # Code repo
└── codeberg.org/
    └── ...
```

Pattern: `work/{server}/{org}/{repo}`

### 3. Agent Swarm (Hecate Triformis)

One human supervises multiple specialized AI agents:

```
                    👤 HUMAN
             (Vision, Decisions, Judgment)
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
   🔥 HECATE       🔥 HECATE       🔥 HECATE
   (DnA Agent)    (AnP Agent)     (TnI Agent)
        │               │               │
        └───────────────┴───────────────┘
                        │
                        ▼
                   🔥 HECATE
                   (DnO Agent)
```

**Agent Specializations:**

| Agent | Role | Personality |
|-------|------|-------------|
| Hecate-DnA | Explorer, Researcher | Curious, thorough, asks questions |
| Hecate-AnP | Architect, Planner | Systematic, trade-off focused |
| Hecate-TnI | Implementer, Tester | Precise, quality-focused |
| Hecate-DnO | Operator, Guardian | Cautious, monitoring, stable |

Agents can also specialize by domain (Backend, Frontend, Infra) or by task.

**Human's Role:**
- Vision: "We need geo-restriction for compliance"
- Decisions: "Use blocklist mode, not allowlist"
- Approval: "This plan looks good, proceed"
- Judgment: "That approach is too complex, simplify"
- Priorities: "Pause marketplace, focus on geo"

Agents handle execution. Human supervises.

### 4. ALC (Agent Life Cycle) Phases

| Phase | Code | Focus |
|-------|------|-------|
| Discovery & Analysis | DnA | Understanding, researching |
| Architecture & Planning | AnP | Designing, planning |
| Testing & Implementation | TnI | Building, quality |
| Deployment & Operations | DnO | Shipping, monitoring |

Each phase produces artifacts (see below).

### 5. Phase Artifacts

```
DnA (Discovery & Analysis)
├── VISION.md           - Why are we doing this?
├── CONTEXT_MAP.md      - Big picture, bounded contexts
├── RESEARCH/           - Spikes, notes, findings
└── REQUIREMENTS.md     - What must it do?
        │
        ▼
AnP (Architecture & Planning)
├── PATHWAY_*.md        - Which context first, why
├── DIVISION_*.md       - Desk design per context
├── ADR/                - Architecture Decision Records
├── PLAN_*.md           - Implementation plans
├── KANBAN.md           - Living task board
└── diagrams/*.svg      - Architecture diagrams
        │
        ▼
TnI (Testing & Implementation)
├── SKELETON.md         - Walking skeleton status
├── src/                - Code
├── test/               - Tests
├── docs/               - Documentation
└── assets/*.svg        - Code diagrams
        │
        ▼
DnO (Deployment & Operations)
├── CHANGELOG.md        - Release notes
├── deploy/             - GitOps manifests
├── RUNBOOK.md          - Operational procedures
└── monitoring/         - Dashboards, alerts
```

---

## The Hecate Workflow

### Venture Ignition Pipeline

```
1. VENTURE BRIEF (Human)
   └── 200-500 words: What? Why? For whom?
                │
                ▼
2. DnA ITERATION (Human + Hecate-DnA)
   └── Questions, clarifications, research
   └── Output: CONTEXT_MAP.md (Big Picture)
                │
                ▼
3. PATHWAY SELECTION (Human decides)
   └── Choose ONE context from the crossroads
   └── This becomes the first Division
                │
                ▼
4. DIVISION DESIGN (Hecate-AnP)
   └── Identify desks (domain slices)
   └── Output: DIVISION_<context>.md
                │
                ▼
5. WALKING SKELETON (Hecate-TnI)
   └── Thin end-to-end implementation
   └── One slice per desk, barely functional
   └── Proves the architecture works
                │
                ▼
6. FLESH OUT (Hecate-TnI, iterative)
   └── Desk by desk, add real functionality
   └── Human reviews, agents implement
                │
                ▼
7. DEPLOY & OBSERVE (Hecate-DnO)
   └── Walking skeleton to production early
   └── Iterate with real feedback
```

### Venture Brief Template

```markdown
# Venture Brief: [Name]

## What
[One paragraph: What are we building?]

## Why
[One paragraph: Why does this matter?]

## For Whom
[Bullet list: Who benefits and how?]

## Initial Scope
[What's in v1? What's explicitly out?]

## Non-Goals
[What are we NOT doing?]
```

~200-500 words. Human writes this. It's the seed.

### Context Map

Output of DnA iteration. Shows bounded contexts and their relationships.

```
┌─────────────────────────────────────────────────────────────┐
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐   │
│  │  CONTEXT A  │────▶│  CONTEXT B  │────▶│  CONTEXT C  │   │
│  └─────────────┘     └─────────────┘     └─────────────┘   │
│         │                   │                              │
│         ▼                   ▼                              │
│  ┌─────────────┐     ┌─────────────┐                      │
│  │  CONTEXT D  │     │  CONTEXT E  │                      │
│  └─────────────┘     └─────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

### Pathway

Human selects ONE context to start. This is the "crossroads decision" - Hecate illuminates the path chosen.

### Division

One context = one Division = one bounded context of software.

A Division has desks (domain slices):

```
         DIVISION: geo_check
              │
    ┌─────────┼─────────┐
    │         │         │
    ▼         ▼         ▼
  DESK      DESK      DESK
  (CMD)     (CMD)     (QRY)

  check_ip  reload    get_status
            _config
```

Each desk is a vertical slice with its own:
- Command/Query
- Handler
- Events (if command)
- Projections (if needed)

### Walking Skeleton

Thin end-to-end implementation:

1. One minimal slice per desk
2. Barely functional but complete path
3. Proves architecture works
4. Deploy to production immediately
5. Then flesh out iteratively

---

## Configuration

### Detection Levels

| Level | Behavior |
|-------|----------|
| passive | Detect type, show context, no suggestions |
| suggest | Detect + offer contextual suggestions (default) |
| aggressive | Deep integration, language idioms, auto-actions |

Configurable per venture and per repo.

### Git Integration

Full trunk-based development support by default:

- Branch age warnings (default: 2h)
- Coordinated cross-repo commits
- Cycle tracking (pull → branch → commit → push → merge)

### Phase Validation

Agent negotiation model:
- Agents check prerequisites with each other
- Proceed when consensus reached
- Human can override with logged justification

Configurable strictness per venture:
- strict: Must have artifacts
- guided: Warns but allows
- advisory: Suggests only
- loose: No validation

---

## Technical Architecture

### Components

| Component | Language | Purpose |
|-----------|----------|---------|
| hecate-daemon | Erlang | Agent runtime, mesh connection, LLM routing |
| hecate-tui | Go | Human command center |
| hecate-corpus | Markdown | Personality, skills, philosophy |
| macula-boot | Elixir | Mesh bootstrap node |
| macula-realm | Elixir | Identity, authentication |

### Agent Implementation

Agents are Erlang processes (actors):
- Lightweight, can spawn many
- Message-based communication
- Supervision trees for fault tolerance
- Can be distributed across mesh

```erlang
%% Spawn a TnI agent for a task
{ok, Pid} = hecate_agent:spawn(tni, #{
    task => <<"geo-restriction">>,
    venture => <<"macula-platform">>
}).

%% Agents communicate
hecate_anp ! {plan_ready, TaskId, PlanFile}.
hecate_tni ! {implement, Plan}.
```

### Cross-Repo Coordination

Agents coordinate commits across repos:

1. Agent completes changes in multiple repos
2. Verifies all tests pass
3. Requests human approval
4. Executes coordinated commit with linked IDs
5. Manifests recorded in Venture repo

---

## Commands Reference

### Venture Management
```
/venture                  # Show current venture
/venture list             # List all ventures
/venture <name>           # Switch venture
/venture new <name>       # Create new venture
/venture templates        # Show available templates
```

### Agent Management
```
/agents                   # List active agents
/agent spawn <type>       # Spawn agent (dna, anp, tni, dno)
/agent <id>               # Check agent status
/agent <id> pause         # Pause agent
/agent <id> retire        # Gracefully terminate
/broadcast <message>      # Message all agents
```

### Task Management
```
/task new "<name>"        # Create task
/task list                # List tasks
/task <name>              # Switch to task
/task close               # Archive completed task
```

### Phase & Artifacts
```
/phase                    # Show current phase
/phase <code>             # Set phase (dna, anp, tni, dno)
/artifact <type>          # Create artifact from template
/kanban                   # Show task kanban
```

### Repo Management
```
/repo                     # Show current repo settings
/repo detect <level>      # Set detection level
/repo build "<cmd>"       # Override build command
```

### Git (Trunk-Based)
```
/status                   # Cross-repo git status
/commit                   # Guided commit
/commit --venture         # Coordinated cross-repo commit
/push                     # Push and optionally PR
/cycle                    # Show trunk-based cycle status
```

---

## Venture as Event Stream

### The Core Insight

**A Venture is not just a repository—it's an aggregate with an event stream.**

Every significant action in a Venture's lifecycle is captured as an event. Artifacts (VISION.md, CONTEXT_MAP.md, etc.) become projections of these events, not primary sources.

```
VENTURE AGGREGATE
├── State (current phase, active agents, task board)
├── Event Stream (complete history)
└── Projections (artifacts, dashboards, reports)
```

### Why Event Sourcing for Ventures?

1. **Complete History** - Every decision, every change, every agent action recorded
2. **Time Travel** - "What did the context map look like before that refactor?"
3. **Auditability** - Perfect record for compliance, learning, AI training
4. **Mesh Distribution** - Events naturally distribute across the mesh
5. **Multi-Agent Coordination** - Agents subscribe to Venture events, react appropriately

### Event Types by Phase

#### Ignition Events
```erlang
%% Venture lifecycle
venture_initiated_v1      %% Venture created with initial brief
venture_paused_v1         %% Work paused (human decision)
venture_resumed_v1        %% Work resumed
venture_completed_v1      %% Venture achieved its goal
venture_archived_v1       %% Venture retired to history
```

#### DnA Phase Events
```erlang
%% Discovery & Analysis
context_map_drafted_v1    %% Initial context map created
context_identified_v1     %% New bounded context discovered
question_raised_v1        %% Clarification needed from human
question_resolved_v1      %% Human answered the question
research_completed_v1     %% Spike/research finished
requirements_captured_v1  %% Requirements documented
```

#### AnP Phase Events
```erlang
%% Architecture & Planning
pathway_selected_v1       %% Human chose which context first
division_designed_v1      %% Desk structure defined
adr_recorded_v1           %% Architecture decision made
plan_drafted_v1           %% Implementation plan created
task_added_v1             %% Task added to kanban
task_estimated_v1         %% Story points assigned
```

#### TnI Phase Events
```erlang
%% Testing & Implementation
skeleton_started_v1       %% Walking skeleton begun
desk_skeleton_complete_v1 %% One desk wired up
desk_fleshed_out_v1       %% Desk fully implemented
test_added_v1             %% Test coverage increased
code_reviewed_v1          %% PR reviewed and approved
```

#### DnO Phase Events
```erlang
%% Deployment & Operations
deployed_to_dev_v1        %% Deployed to dev environment
deployed_to_staging_v1    %% Deployed to staging
deployed_to_prod_v1       %% Production deployment
incident_recorded_v1      %% Production issue logged
runbook_updated_v1        %% Operational docs updated
```

### Domain Events vs Agent Telemetry

**Critical distinction:** Domain events capture WHAT was accomplished, not WHO did it.

The litmus test: *"If a human did this work instead of an agent, would this event still be recorded?"*

| Event | Domain Event? | Reasoning |
|-------|---------------|-----------|
| `context_map_drafted_v1` | ✅ Yes | We'd record that a context map was drafted |
| `agent_spawned_v1` | ❌ No | "Employee clocked in" isn't project history |
| `desk_tests_passed_v1` | ✅ Yes | We'd record that tests passed |
| `tokens_consumed_v1` | ❌ No | "Sarah drank 3 coffees" isn't project history |

Agent lifecycle events (`agent_spawned`, `agent_retired`, `task_picked_up`) are **operational telemetry**, not domain events. They belong in a separate observability system.

### Projections

Events project into multiple views:

| Projection | Purpose | Updated By |
|------------|---------|------------|
| **Artifact Files** | VISION.md, CONTEXT_MAP.md, etc. | File writer on relevant events |
| **TUI Dashboard** | Real-time Venture status | Live subscription |
| **Kanban Board** | Task tracking | task_* events |
| **Progress Metrics** | Velocity, completion rate | Aggregate domain events |
| **Audit Log** | Compliance record | All domain events |

**Key Insight:** Artifacts become projections, not primary sources. When a human edits VISION.md directly, that's captured as `vision_manually_updated_v1` event.

### Storage Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                   VENTURE EVENT STREAM                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Local (ReckonDB)                                            │
│  ├── Primary event store                                     │
│  ├── Fast queries for TUI                                    │
│  └── Survives network partition                              │
│                                                               │
│  Mesh (Macula DHT)                                           │
│  ├── Distributed replication                                 │
│  ├── Cross-device sync                                       │
│  └── Content-addressed for integrity                         │
│                                                               │
│  Venture Repo (Git)                                          │
│  ├── Artifact projections (markdown files)                   │
│  ├── Human-readable history                                  │
│  └── Versioned snapshots                                     │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Example: Event Flow

```
Human: "We need geo-restriction for compliance"
        │
        ▼
[venture_initiated_v1]
├── venture_id: "macula-geo"
├── brief: "Geo-restriction for compliance..."
└── initiated_by: "human:rl"
        │
        ▼
Projection: Creates ~/work/.../macula-geo/BRIEF.md
        │
        ▼
Hecate-DnA agent subscribes, starts work
        │
        ▼
[context_identified_v1]
├── context: "geo_check"
├── description: "IP-based country detection"
└── identified_by: "agent:dna-001"
        │
        ▼
Projection: Updates CONTEXT_MAP.md
        │
        ▼
... (more events) ...
        │
        ▼
[deployed_to_prod_v1]
├── version: "1.0.0"
├── deployed_by: "agent:dno-001"
└── approved_by: "human:rl"
        │
        ▼
Venture complete! Full history preserved.
```

### Benefits

1. **Nothing Lost** - Every decision, draft, iteration preserved
2. **AI Training** - Event streams are perfect training data
3. **Reproducibility** - Replay events to recreate any state
4. **Distributed** - Naturally works across mesh nodes
5. **Async-First** - Agents work independently, sync via events

---

## Agent Swarm Architecture

### Specialists + Generalist Pool

The agent swarm uses a hybrid model: long-lived phase specialists for continuity, ephemeral generalists for burst capacity.

```
┌─────────────────────────────────────────────────────────────────────┐
│                       VENTURE AGENT SWARM                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  SPECIALISTS (Long-lived, one per phase)                             │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐                 │
│  │   DnA   │  │   AnP   │  │   TnI   │  │   DnO   │                 │
│  │Specialist│ │Specialist│ │Specialist│ │Specialist│                 │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘                 │
│       │            │            │            │                        │
│       └────────────┴─────┬──────┴────────────┘                       │
│                          │                                            │
│                          ▼                                            │
│  GENERALIST POOL (Ephemeral, task-scoped)                            │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐  ┌───┐   │     │
│  │  │ G │  │ G │  │ G │  │   │  │   │  │   │  │   │  │   │   │     │
│  │  │ 1 │  │ 2 │  │ 3 │  │ - │  │ - │  │ - │  │ - │  │ - │   │     │
│  │  └───┘  └───┘  └───┘  └───┘  └───┘  └───┘  └───┘  └───┘   │     │
│  │  active active active  ←── available slots (max 8) ──→     │     │
│  └─────────────────────────────────────────────────────────────┘     │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Specialists

Four specialists spawn when the Venture initiates. They're long-lived and phase-aware:

| Specialist | Responsibilities |
|------------|------------------|
| **DnA Specialist** | Research, context discovery, requirements gathering |
| **AnP Specialist** | Architecture decisions, division design, planning |
| **TnI Specialist** | Implementation, testing, code review coordination |
| **DnO Specialist** | Deployment, monitoring, incident response |

**Specialist traits:**
- Maintain phase context and memory across tasks
- Coordinate work within their phase
- Request generalists when workload exceeds capacity
- Hand off to next phase specialist at transitions
- Idle but persist when not in active phase

### Generalists

Generalists spawn on-demand when specialists need parallel capacity:

```
DnA Specialist needs to research 4 contexts in parallel
    ↓
Requests 3 generalists (specialist handles 1 itself)
    ↓
Generalists complete research, report back
    ↓
Generalists retire, specialist consolidates findings
```

**Generalist traits:**
- Task-scoped (retire when task completes)
- No cross-task memory
- Assigned to and coordinated by a specialist
- Cannot spawn other generalists

### Pool Configuration

```toml
# venture.toml or ~/.config/hecate-tui/config.toml
[agents.pool]
min_generalists = 0        # No idle generalists by default
max_generalists = 8        # Hard cap on concurrent assistants
idle_timeout = "5m"        # Retire idle generalists after 5 min

[agents.specialists]
spawn_on_initiation = true # All 4 specialists spawn immediately
idle_allowed = true        # Specialists can idle (don't retire)
```

---

## Agent Performance Measurement

Agent performance is tracked via **telemetry**, separate from domain events.

### Telemetry Streams

```
┌─────────────────────────────────────────────────────────────┐
│                    AGENT TELEMETRY                           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Metrics (Quantitative)                                      │
│  ├── tokens_consumed        - LLM token usage per task       │
│  ├── task_duration_ms       - Time to complete task          │
│  ├── tasks_completed        - Count of completed tasks       │
│  ├── error_count            - Failures requiring retry       │
│  └── handoff_count          - Work transfers between agents  │
│                                                               │
│  Traces (Request Flow)                                       │
│  ├── task_id                - Unique task identifier         │
│  ├── agent_id               - Which agent handled it         │
│  ├── parent_task_id         - For subtask relationships      │
│  └── timestamps             - Start, checkpoints, end        │
│                                                               │
│  Logs (Qualitative)                                          │
│  ├── decisions              - Why agent chose an approach    │
│  ├── blockers               - What slowed progress           │
│  └── quality_notes          - Self-assessment of output      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Performance Dimensions

| Dimension | Metrics | Used For |
|-----------|---------|----------|
| **Efficiency** | tokens/task, duration, cost | Resource optimization |
| **Quality** | rework_rate, review_rejections | Output improvement |
| **Throughput** | tasks/hour, parallel_capacity | Capacity planning |
| **Reliability** | error_rate, retry_count | Stability monitoring |
| **Collaboration** | handoff_clarity, specialist_load | Team balance |

### Agent Scorecards

Aggregate telemetry into per-agent scorecards:

```
┌─────────────────────────────────────────────────────────────┐
│  AGENT SCORECARD: DnA-Specialist                             │
│  Venture: macula-geo | Period: Last 7 days                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Tasks Completed:     12        Avg Duration:    8.3 min     │
│  Tokens Used:         45,230    Avg Tokens/Task: 3,769       │
│  Error Rate:          8.3%      Rework Rate:     16.7%       │
│  Generalists Used:    6         Delegation Rate: 50%         │
│                                                               │
│  Quality Signals:                                             │
│  ├── Human approvals on first try: 83%                       │
│  ├── Context maps accepted without revision: 75%             │
│  └── Research depth rating (human): 4.2/5                    │
│                                                               │
│  Cost:                                                        │
│  ├── LLM API cost: $2.47                                     │
│  └── Estimated human-equivalent hours saved: 18h             │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Human Feedback Loop

Performance measurement requires human input for quality signals:

```
Task completed → Human reviews output → Quick rating (1-5 or 👍/👎)
                                     → Optional: specific feedback
                                     → Stored as telemetry, not domain event
```

**Feedback types:**
- **Approval signals**: Accept, request revision, reject
- **Quality ratings**: 1-5 scale on specific dimensions
- **Freeform notes**: "Too verbose", "Missed edge case", "Excellent"

### Telemetry Storage

| Storage | Purpose | Retention |
|---------|---------|-----------|
| **Prometheus/OpenTelemetry** | Real-time metrics, alerting | 30 days |
| **Structured Logs** | Debugging, audit | 90 days |
| **Scorecard Snapshots** | Historical comparison | Indefinite |
| **Aggregated Stats** | Trend analysis, billing | Indefinite |

### Why Separate from Domain Events?

1. **Different consumers** - Ops team vs. project stakeholders
2. **Different retention** - Telemetry can age out, domain events are forever
3. **Different privacy** - Token costs may be sensitive, project progress isn't
4. **Different scale** - Telemetry is high-volume, domain events are sparse
5. **Clean domain model** - Business events stay focused on business outcomes

---

## Skill System

### Overview

Skills are knowledge packages that agents load to work effectively in specific contexts. The skill system uses **profiles with layered detection**: auto-detection provides defaults, profiles bundle common patterns, and per-repo overrides handle edge cases.

### Skill Layers

```
┌─────────────────────────────────────────────────────────────┐
│                      SKILL LOADING                           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Layer 1: Auto-Detection (Baseline)                          │
│  ├── Scan for markers: rebar.config, mix.exs, go.mod        │
│  ├── Load core language skills automatically                 │
│  └── Zero config for common cases                            │
│                                                               │
│  Layer 2: Profiles (Reusable Bundles)                        │
│  ├── erlang-cqrs: evoq + vertical-slicing + screaming-arch  │
│  ├── go-tui: bubbletea + lipgloss + tui-ux-patterns         │
│  ├── elixir-phoenix: phoenix + ecto + liveview              │
│  └── Organization-wide consistency                           │
│                                                               │
│  Layer 3: Per-Repo Override                                  │
│  ├── skills_add: add specific skills                         │
│  ├── skills_remove: exclude irrelevant skills                │
│  └── Full control when needed                                │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Profile Definition

Profiles live in `hecate-corpus/profiles/`:

```toml
# hecate-corpus/profiles/erlang-cqrs.toml
[profile]
name = "erlang-cqrs"
description = "Erlang event-sourced CQRS with ReckonDB/Evoq"

[profile.inherits]
profiles = ["erlang-core", "erlang-otp"]

[profile.skills]
required = [
    "erlang-evoq",
    "vertical-slicing",
    "screaming-architecture",
    "cqrs-patterns",
    "event-sourcing"
]

[profile.detection]
markers = ["rebar.config", "apps/*/src/*_aggregate.erl"]
confidence = "high"  # Auto-apply if markers found
```

### Venture Configuration

```toml
# venture.toml
[venture]
name = "macula-platform"

# Default profile for all repos in this Venture
default_profile = "erlang-cqrs"

[repos."hecate-social/hecate-daemon"]
role = "core"
profile = "erlang-cqrs"           # Explicit (or auto-detected)
skills_add = ["hecate-mesh"]      # Add daemon-specific skills
skills_remove = ["erlang-jsx"]    # We use OTP json, not jsx

[repos."hecate-social/hecate-tui"]
role = "client"
profile = "go-tui"
skills_add = ["hecate-tui-commands"]
```

### Skill Types

| Type | Location | Purpose |
|------|----------|---------|
| **Philosophy** | `philosophy/` | Mental models (DDD, vertical slicing) |
| **Guides** | `guides/` | How-to knowledge (division sequences) |
| **Codegen** | `skills/codegen/` | Templates and patterns |
| **Antipatterns** | `skills/` | What NOT to do |
| **Language** | `skills/{lang}/` | Language-specific idioms |
| **Framework** | `skills/{framework}/` | Framework conventions |

### Detection Markers

```toml
# Built-in detection rules
[detection.erlang]
markers = ["rebar.config", "*.erl", "src/*.app.src"]
skills = ["erlang-core"]

[detection.elixir]
markers = ["mix.exs", "*.ex", "*.exs"]
skills = ["elixir-core"]

[detection.go]
markers = ["go.mod", "go.sum", "*.go"]
skills = ["go-core"]

[detection.phoenix]
markers = ["mix.exs", "lib/*_web/"]
requires = ["elixir"]
skills = ["elixir-phoenix", "elixir-liveview"]

[detection.evoq]
markers = ["rebar.config", "*_aggregate.erl", "*_v1.erl"]
requires = ["erlang"]
skills = ["erlang-evoq", "cqrs-patterns"]
```

### Token Efficiency

Skills are loaded on-demand to minimize token usage:

1. **Embedded skills** - Always loaded (core philosophy, ~500 tokens)
2. **Profile skills** - Loaded when repo is active (~2000 tokens)
3. **On-demand skills** - Loaded when specific task requires (~500-1000 tokens each)

```
Agent working on hecate-daemon:
├── Embedded: SOUL.md, core principles (always)
├── Profile: erlang-cqrs bundle (on repo open)
└── On-demand: CODEGEN_ERLANG_EVOQ.md (when writing aggregate)
```

---

## Mesh Distribution

### v1: Local-Only

All agents run on the local daemon where the TUI is connected:

```
┌─────────────────────────────────────────┐
│  LOCAL MACHINE (hecate-daemon)           │
│  ├── DnA Specialist                      │
│  ├── AnP Specialist                      │
│  ├── TnI Specialist                      │
│  ├── DnO Specialist                      │
│  └── Generalist Pool (0-8)               │
└─────────────────────────────────────────┘
         │
         │ (mesh for data sync only)
         ▼
    Macula Mesh (Venture events, artifacts)
```

**Why local-only for v1:**
- Simpler to implement and debug
- No network failure handling for agent coordination
- Works fully offline
- Proves the agent model before adding distribution complexity

The mesh is still used for:
- Venture event replication across devices
- Artifact synchronization
- Capability announcements (for future discovery)

### Future: Hybrid with Preference

Evolution path when distribution is needed:

```toml
# venture.toml (future)
[agents]
default_placement = "local"  # Specialists and generalists local

[agents.overflow]
enabled = true
nodes = ["beam01.lab", "beam02.lab"]  # Overflow destinations
threshold = 4  # Overflow when >4 generalists needed locally

[agents.placement]
# Explicit placement for resource-intensive roles
tni_specialist = "beam03.lab"  # Has GPU for ML tests
```

**Future capabilities:**
- Generalist overflow to remote nodes when local capacity exceeded
- Explicit placement for resource requirements (GPU, memory)
- Venture homing for shared/team scenarios
- Capability-based auto-placement

---

## Team Collaboration

### Evolution Path

Team collaboration follows a staged evolution:

```
v1: SINGLE HUMAN                 v2: SEQUENTIAL HANDOFF           v3: ROLE-BASED
┌─────────────────┐              ┌─────────────────┐              ┌─────────────────┐
│ Venture         │              │ Venture         │              │ Venture         │
│ └── Owner: rl   │      →       │ └── Owner: rl   │      →       │ └── Humans:     │
│ └── Agents: 4+N │              │ └── Handoff Log │              │     ├── rl (own)│
│                 │              │ └── Agents: 4+N │              │     ├── alice   │
└─────────────────┘              └─────────────────┘              │     └── bob     │
                                                                  └─────────────────┘
```

### v1: Single Human per Venture

One human owns each Venture. Agents respond only to that human.

```toml
# venture.toml
[venture]
name = "macula-platform"
owner = "rl"  # Only rl can interact with agents
```

**Why single-human for v1:**
- No conflict resolution needed
- Clear accountability
- Simpler agent interactions
- Event stream captures everything for future handoff

### v2: Sequential Handoff (Future)

One active human at a time, with explicit handoff:

```
[handoff_initiated_v1]
├── from: "rl"
├── to: "alice"
├── context: "DnA complete, ready for AnP"
└── briefing_requested: true
    ↓
Agents brief alice on current state
    ↓
[handoff_completed_v1]
├── new_owner: "alice"
└── acknowledged: true
```

The event-sourced model naturally supports this—alice can replay events to understand history.

### v3: Role-Based Access (Future)

Multiple humans with specific roles:

| Role | Permissions |
|------|-------------|
| **Owner** | All phases, all decisions, can handoff |
| **Reviewer** | Approve/reject in specific phases |
| **Contributor** | Submit work, cannot approve |
| **Observer** | Read-only, can comment |

Agents enforce role boundaries—a contributor can't approve architecture decisions.

---

## Telemetry Infrastructure

### Architecture: Embedded + Optional Export

SQLite stores telemetry locally by default. Optional Prometheus export for power users.

```
┌─────────────────────────────────────────────────────────────┐
│                    TELEMETRY STORAGE                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ~/.hecate/telemetry.db (SQLite - always on)                 │
│  ├── agent_metrics   - time-series: tokens, duration, errors │
│  ├── task_traces     - spans with parent relationships       │
│  └── agent_logs      - structured logs with severity         │
│                                                               │
│  All records include: venture_id, agent_id, timestamp        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
         │
         │ (optional, if enabled)
         ▼
┌─────────────────────────────────────────────────────────────┐
│  Prometheus Export (:9090/metrics)                           │
│  ├── hecate_tokens_total{venture, agent, model}              │
│  ├── hecate_task_duration_seconds{venture, agent, phase}     │
│  ├── hecate_tasks_completed_total{venture, agent}            │
│  └── hecate_errors_total{venture, agent, type}               │
└─────────────────────────────────────────────────────────────┘
```

### Venture Attribution

All telemetry is attributed to a Venture for cost tracking and analysis:

```sql
-- agent_metrics table
CREATE TABLE agent_metrics (
    id INTEGER PRIMARY KEY,
    venture_id TEXT NOT NULL,    -- Which Venture
    agent_id TEXT NOT NULL,      -- Which agent
    metric_name TEXT NOT NULL,   -- tokens_used, task_duration, etc.
    metric_value REAL NOT NULL,
    labels TEXT,                 -- JSON: {model, phase, task_type}
    timestamp INTEGER NOT NULL
);

-- Indexes for common queries
CREATE INDEX idx_metrics_venture ON agent_metrics(venture_id, timestamp);
CREATE INDEX idx_metrics_agent ON agent_metrics(agent_id, timestamp);
```

### Configuration

```toml
# ~/.config/hecate-tui/config.toml
[telemetry]
enabled = true
storage = "sqlite"        # Always SQLite
retention_days = 30       # Auto-cleanup old data

[telemetry.export.prometheus]
enabled = false           # Disabled by default
port = 9090
```

### TUI Commands

```
/metrics                         # Summary across all Ventures
/metrics venture macula-geo      # Metrics for specific Venture
/scorecard dna-specialist        # Agent scorecard
/cost                            # LLM cost breakdown by Venture
/cost macula-geo                 # Cost for specific Venture
```

### Why This Approach

1. **Works offline** - SQLite has no external dependencies
2. **Zero config default** - Just works out of the box
3. **Venture-attributed** - Every metric tied to a Venture for billing/analysis
4. **Power user friendly** - Enable Prometheus for Grafana dashboards
5. **Retention managed** - Auto-cleanup prevents unbounded growth

---

## Human Feedback UX

### Principle: Don't Add Steps, Enhance Existing Interactions

Feedback collection must be frictionless. The approach: leverage existing approval flow as implicit feedback, offer optional explicit feedback for depth.

### Feedback Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    FEEDBACK COLLECTION                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Layer 1: Implicit (Zero Effort)                             │
│  ├── Approve output    → positive signal                     │
│  ├── Request changes   → negative signal + reason            │
│  ├── Reject            → strong negative signal              │
│  └── Time-to-approve   → confidence indicator                │
│                                                               │
│  Layer 2: Quick React (Optional, Inline)                     │
│  ├── [y] 👍 good       → explicit positive                   │
│  ├── [n] 👎 needs work → explicit negative                   │
│  ├── [c] 📝 comment    → open note input                     │
│  └── [Enter] skip      → no explicit signal                  │
│                                                               │
│  Layer 3: Async Detailed (Power User)                        │
│  └── /feedback {agent} "detailed note about quality"         │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Inline Quick React

After agent output, optional single-keypress feedback:

```
┌─────────────────────────────────────────────────────────────┐
│ DnA-Specialist: Here's the context map:                      │
│                                                              │
│ [context map content...]                                     │
│                                                              │
│ ─────────────────────────────────────────────────────────── │
│ [y] good  [n] needs work  [c] comment  [Enter] continue     │
└─────────────────────────────────────────────────────────────┘
```

- Appears briefly after significant outputs
- Disappears on any key (including Enter to skip)
- No interruption to flow if ignored

### Phase Transition Summary

At phase transitions, aggregate signals into phase rating:

```
┌─────────────────────────────────────────────────────────────┐
│ DnA PHASE COMPLETE                                           │
│                                                              │
│ Implicit signals:  8 approvals, 2 change requests           │
│ Explicit signals:  5 👍, 1 👎                                │
│ Derived rating:    4.2/5                                    │
│                                                              │
│ Proceeding to AnP...                                        │
└─────────────────────────────────────────────────────────────┘
```

### TUI Commands

```
/feedback {agent} "note"    # Async detailed feedback
/signals                    # View recent feedback signals
/signals dna-specialist     # Signals for specific agent
```

### Why This Works

1. **Zero friction default** - Approval flow already happens
2. **Opt-in depth** - Quick react when human wants to signal
3. **Non-blocking** - Skip with Enter, no forced interaction
4. **Aggregated insight** - Phase summaries derive from signals
5. **Power user escape hatch** - `/feedback` for detailed notes

---

## Cost Attribution

### Full Hierarchy + Model-Aware

Every LLM call is attributed with full context for flexible analysis:

```sql
CREATE TABLE llm_calls (
    id INTEGER PRIMARY KEY,
    venture_id TEXT NOT NULL,
    agent_id TEXT NOT NULL,
    task_id TEXT,              -- NULL for non-task calls
    model TEXT NOT NULL,       -- claude-3-opus, ollama/llama3, etc.
    tokens_in INTEGER NOT NULL,
    tokens_out INTEGER NOT NULL,
    cost_usd REAL,             -- NULL for local models
    timestamp INTEGER NOT NULL
);
```

### Progressive Disclosure

Show summaries by default, drill down on demand:

```
/cost                           # Venture-level summary (default)

Venture                  Tokens        Cost (USD)
─────────────────────────────────────────────────
macula-geo               145,230       $4.35
macula-platform          892,100       $26.76
hecate-daemon            234,500       $7.04
─────────────────────────────────────────────────
Total (30 days)                        $38.15
```

```
/cost macula-geo                # Agent breakdown

Agent                    Tokens        Cost (USD)   % of Venture
─────────────────────────────────────────────────────────────
DnA-Specialist           45,000        $1.35        31%
AnP-Specialist           62,000        $1.86        43%
TnI-Specialist           28,000        $0.84        19%
Generalists (3)          10,230        $0.31         7%
─────────────────────────────────────────────────────────────
```

```
/cost macula-geo --tasks        # Task-level detail

Task                           Agent         Tokens    Cost
────────────────────────────────────────────────────────────
Draft context map              DnA           12,000    $0.36
Research geo_check context     DnA            8,500    $0.26
Design geo_check division      AnP           18,000    $0.54
...
```

```
/cost --by-model                # Model breakdown

Model                    Tokens        Cost (USD)
─────────────────────────────────────────────────
claude-3-opus            45,000        $2.70
claude-3-sonnet          80,000        $1.20
claude-3-haiku           20,230        $0.05
ollama/llama3            (local)       $0.00
─────────────────────────────────────────────────
```

### Model Pricing

Pricing stored in config, updated as providers change:

```toml
# ~/.config/hecate-tui/config.toml
[cost.models]
# Per 1K tokens (input/output)
"claude-3-opus" = { input = 0.015, output = 0.075 }
"claude-3-sonnet" = { input = 0.003, output = 0.015 }
"claude-3-haiku" = { input = 0.00025, output = 0.00125 }
"gpt-4-turbo" = { input = 0.01, output = 0.03 }
"ollama/*" = { input = 0.0, output = 0.0 }  # Local = free
```

### Use Cases

| Question | Command |
|----------|---------|
| What's my total spend? | `/cost` |
| Which Venture costs most? | `/cost` |
| Which phase is expensive? | `/cost {venture}` |
| What tasks burn tokens? | `/cost {venture} --tasks` |
| Should I use a cheaper model? | `/cost --by-model` |
| Compare Venture efficiency | `/cost --per-task-avg` |

### Why Full Attribution

1. **Optimization** - Identify expensive tasks, switch models
2. **Budgeting** - Set per-Venture or per-month limits
3. **Comparison** - Which Venture is most efficient?
4. **Billing** - If Ventures have different funding sources
5. **Learning** - Understand cost drivers over time

---

## Open Questions

### Answered

| Question | Answer |
|----------|--------|
| Agent Persistence | Yes, specialists survive restart via event replay |
| Agent Memory | Event streams + projections provide context |
| Agent Spawning Model | Specialists (4 long-lived) + Generalist Pool (0-8 ephemeral) |
| Domain vs Telemetry | Domain events = business outcomes; Telemetry = operational metrics |
| Skill System | Profiles + layered detection: auto-detect → profile → per-repo override |
| Mesh Distribution | v1: Local-only; Future: Hybrid with overflow to remote nodes |
| Team Collaboration | v1: Single human per Venture; v2: Sequential handoff; v3: Role-based |
| Telemetry Infrastructure | SQLite embedded + optional Prometheus export; Venture-attributed |
| Human Feedback UX | Hybrid: approval-is-feedback + optional quick react (y/n/c) |
| Cost Attribution | Full hierarchy (Venture→Agent→Task) + model-aware; progressive disclosure |

### Remaining

(All key questions answered)
3. **Team Collaboration:** Multiple humans + shared agent pool?
4. **Telemetry Infrastructure:** Prometheus vs custom vs hybrid?
5. **Human Feedback UX:** How to make rating frictionless in TUI?
6. **Cost Attribution:** How to allocate LLM costs across Ventures/tasks?

---

## References

- Hecate Mythology: Three-bodied goddess of crossroads
- Walking Skeleton: Alistair Cockburn's pattern
- Trunk-Based Development: trunkbaseddevelopment.com
- Actor Model: Erlang/OTP supervision trees
- Vertical Slicing: Feature-based architecture
- DDD Context Mapping: Bounded context identification

---

## Next Steps

1. Complete Division and Walking Skeleton documentation
2. Prototype agent spawning in hecate-daemon
3. Design TUI command center view
4. Implement Venture repo structure
5. Create skill profiles in hecate-corpus
