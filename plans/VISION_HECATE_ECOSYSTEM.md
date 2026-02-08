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

### 1. Torch

**A Torch is an idea you're illuminating** - a business endeavor that manifests across multiple repositories.

Not "a collection of repos" but "the thing I'm building" - represented as a dedicated repository that acts as the project's brain.

```
~/work/github.com/hecate-social/macula-platform/    # THE TORCH
├── VISION.md                 # Why does this exist?
├── CONTEXT_MAP.md            # Big picture
├── torch.toml                # Repo references, config
├── tasks/                    # Task artifacts (by ALC phase)
├── decisions/                # ADRs
└── diagrams/                 # Architecture SVGs
```

The Torch repo references code repos:

```toml
# torch.toml
[torch]
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
│   │   ├── macula-platform/     # Torch repo
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
├── CARTWHEEL_*.md      - Spoke design per context
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

### Torch Ignition Pipeline

```
1. TORCH BRIEF (Human)
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
   └── This becomes the first Cartwheel
                │
                ▼
4. CARTWHEEL DESIGN (Hecate-AnP)
   └── Identify spokes (domain slices)
   └── Output: CARTWHEEL_<context>.md
                │
                ▼
5. WALKING SKELETON (Hecate-TnI)
   └── Thin end-to-end implementation
   └── One slice per spoke, barely functional
   └── Proves the architecture works
                │
                ▼
6. FLESH OUT (Hecate-TnI, iterative)
   └── Spoke by spoke, add real functionality
   └── Human reviews, agents implement
                │
                ▼
7. DEPLOY & OBSERVE (Hecate-DnO)
   └── Walking skeleton to production early
   └── Iterate with real feedback
```

### Torch Brief Template

```markdown
# Torch Brief: [Name]

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

### Cartwheel

One context = one Cartwheel = one process service.

A Cartwheel has spokes (domain slices):

```
         CARTWHEEL: geo_check
              │
    ┌─────────┼─────────┐
    │         │         │
    ▼         ▼         ▼
  SPOKE     SPOKE     SPOKE
  (CMD)     (CMD)     (QRY)

  check_ip  reload    get_status
            _config
```

Each spoke is a vertical slice with its own:
- Command/Query
- Handler
- Events (if command)
- Projections (if needed)

### Walking Skeleton

Thin end-to-end implementation:

1. One minimal slice per spoke
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

Configurable per torch and per repo.

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

Configurable strictness per torch:
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
| hecate-agents | Markdown | Personality, skills, philosophy |
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
    torch => <<"macula-platform">>
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
5. Manifests recorded in Torch repo

---

## Commands Reference

### Torch Management
```
/torch                    # Show current torch
/torch list               # List all torches
/torch <name>             # Switch torch
/torch new <name>         # Create new torch
/torch templates          # Show available templates
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
/commit --torch           # Coordinated cross-repo commit
/push                     # Push and optionally PR
/cycle                    # Show trunk-based cycle status
```

---

## Torch as Event Stream

### The Core Insight

**A Torch is not just a repository—it's an aggregate with an event stream.**

Every significant action in a Torch's lifecycle is captured as an event. Artifacts (VISION.md, CONTEXT_MAP.md, etc.) become projections of these events, not primary sources.

```
TORCH AGGREGATE
├── State (current phase, active agents, task board)
├── Event Stream (complete history)
└── Projections (artifacts, dashboards, reports)
```

### Why Event Sourcing for Torches?

1. **Complete History** - Every decision, every change, every agent action recorded
2. **Time Travel** - "What did the context map look like before that refactor?"
3. **Auditability** - Perfect record for compliance, learning, AI training
4. **Mesh Distribution** - Events naturally distribute across the mesh
5. **Multi-Agent Coordination** - Agents subscribe to Torch events, react appropriately

### Event Types by Phase

#### Ignition Events
```erlang
%% Torch lifecycle
torch_ignited_v1          %% Torch created with initial brief
torch_paused_v1           %% Work paused (human decision)
torch_resumed_v1          %% Work resumed
torch_completed_v1        %% Torch achieved its goal
torch_archived_v1         %% Torch retired to history
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
cartwheel_designed_v1     %% Spoke structure defined
adr_recorded_v1           %% Architecture decision made
plan_drafted_v1           %% Implementation plan created
task_added_v1             %% Task added to kanban
task_estimated_v1         %% Story points assigned
```

#### TnI Phase Events
```erlang
%% Testing & Implementation
skeleton_started_v1       %% Walking skeleton begun
spoke_skeleton_complete_v1 %% One spoke wired up
spoke_fleshed_out_v1      %% Spoke fully implemented
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

#### Agent Events
```erlang
%% Agent lifecycle (cross-phase)
agent_spawned_v1          %% New agent created for task
agent_task_assigned_v1    %% Agent picked up work
agent_task_completed_v1   %% Agent finished work
agent_retired_v1          %% Agent gracefully stopped
agent_handed_off_v1       %% Work transferred between agents
```

### Projections

Events project into multiple views:

| Projection | Purpose | Updated By |
|------------|---------|------------|
| **Artifact Files** | VISION.md, CONTEXT_MAP.md, etc. | File writer on relevant events |
| **TUI Dashboard** | Real-time Torch status | Live subscription |
| **Kanban Board** | Task tracking | task_* events |
| **Agent Registry** | Active agents | agent_* events |
| **Metrics** | Progress, velocity | Aggregate all events |
| **Audit Log** | Compliance record | All events |

**Key Insight:** Artifacts become projections, not primary sources. When a human edits VISION.md directly, that's captured as `vision_manually_updated_v1` event.

### Storage Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                     TORCH EVENT STREAM                       │
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
│  Torch Repo (Git)                                            │
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
[torch_ignited_v1]
├── torch_id: "macula-geo"
├── brief: "Geo-restriction for compliance..."
└── ignited_by: "human:rl"
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
Torch complete! Full history preserved.
```

### Benefits

1. **Nothing Lost** - Every decision, draft, iteration preserved
2. **AI Training** - Event streams are perfect training data
3. **Reproducibility** - Replay events to recreate any state
4. **Distributed** - Naturally works across mesh nodes
5. **Async-First** - Agents work independently, sync via events

---

## Open Questions

1. **Skill System:** How do language/framework skills integrate with detection?
2. **Agent Persistence:** Do agents survive daemon restart? (Answer: Yes, via event replay)
3. **Mesh Distribution:** How are agents distributed across mesh nodes?
4. **Team Collaboration:** Multiple humans + shared agent pool?
5. **Agent Memory:** How do agents learn and retain context? (Answer: Event streams + projections)

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

1. Complete Cartwheel and Walking Skeleton documentation
2. Design skill system integration
3. Prototype agent spawning in hecate-daemon
4. Design TUI command center view
5. Implement Torch repo structure
