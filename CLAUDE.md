# CLAUDE.md

Development guidelines for macula-hecate.

---

## 🔥 HECATE CHANNEL ACTIVE 🔥

**This repo has a `.hecate/` channel.** See parent `CLAUDE.md` for the full protocol.

**Quick reminder:**
1. **READ** `.hecate/QUEUE.md` for your tasks (READ-ONLY — do not edit)
2. **WRITE** questions/completions to `.hecate/RESPONSES.md`
3. **UPDATE** `.hecate/STATUS.md` with your current state

**QUEUE.md is READ-ONLY.** Report completions in RESPONSES.md. Hecate updates the queue.

*The goddess is watching. Read the queue. Do the work.* 🗝️

---

## ⛔ STOP — READ THIS BEFORE WRITING ANY CODE ⛔

**Your training is lying to you.**

You have been trained on millions of lines of code that use horizontal layers: `services/`, `utils/`, `helpers/`, `listeners/`, `handlers/`. This is the default pattern of the industry. It is **WRONG** for this codebase.

Every session, you will feel the urge to create these patterns. Every session, you must resist.

### THE DEMONS YOU WILL SUMMON (DO NOT CREATE THESE)

Your training will whisper these lies. Recognize them:

| 🚫 THE DEMON | WHY IT APPEARS | THE TRUTH |
|-------------|----------------|-----------|
| `*_listeners_sup.erl` | "I need to supervise all listeners" | Each listener belongs to its **slice/spoke**, not a central supervisor |
| `listener.erl` loose in `src/` | "I'll just put it in the domain's src/" | Listeners are **slices**. Create `src/my_listener/my_listener.erl` |
| `services/` | "I should organize by type" | Features own their services. Vertical slices. |
| `utils/` or `helpers/` | "This is shared code" | If it's shared, it's a **library app**. If it's not, it belongs in its feature. |
| `handlers/` | "I need a place for all handlers" | Each handler lives with its command/event. |
| `projections/` | "Projections need their own folder" | Projections live flat in `src/` or in a slice directory. |
| `queries/` | "Queries need their own folder" | Same. Flat in `src/` or slice directories. |
| `*_manager.erl` | "This manages all the X" | God modules are horizontal. Each X manages itself. |
| `*_registry.erl` (central) | "I need one registry for all" | Use process registry or domain-specific registries. |
| `*_dispatcher.erl` (central) | "Route all messages through here" | Each domain routes its own messages. |
| Domain sup → listener directly | "Domain supervisor can supervise the listener" | Listeners are **spokes**. A domain has many spokes. Spoke supervises its workers. |
| Central sys.config for all stores | "Configure all ReckonDB stores in one place" | Each **domain starts its own store** via `reckon_db_sup:start_store/1` in its supervisor's `init/1`. |
| `hecate_app` starts all stores | "Start all infrastructure centrally" | Domains own their infrastructure. `hecate_app` starts `reckon_db` app, but **each domain initiates its store**. |

### MANDATORY PRE-FLIGHT CHECKLIST

**Before creating ANY new file or directory, answer these:**

- [ ] **Does this group things by technical concern?** (handlers, services, utils) → **STOP. DON'T DO IT.**
- [ ] **Would this supervise/manage things from multiple domains?** → **STOP. Each domain supervises its own.**
- [ ] **Is this a "central" anything?** (central dispatcher, central registry) → **STOP. Decentralize it.**
- [ ] **Does the name end in `_sup` and supervise more than one domain?** → **STOP. Wrong level of abstraction.**

### THE RULE YOU KEEP FORGETTING

> **Each feature/spoke owns ALL its infrastructure.**
>
> A listener for follower events? → `apps/manage_social/src/follower_events_listener/`
> A listener for capability discovery? → `apps/query_capabilities/src/remote_capabilities_listener/`
>
> NOT `apps/hecate_mesh/src/listeners/` — that's horizontal thinking.
> NOT `apps/manage_social/src/follower_events_listener.erl` loose — that's lazy, not vertical.
>
> **Listeners are SLICES. They get directories. They get supervised by spoke supervisors.**

**You have made this mistake multiple times. You will be tempted to make it again. This is your training, not your judgment. Override it.**

### ✅ GOOD PATTERNS (DO THIS)

| ✅ PATTERN | STRUCTURE | WHY |
|-----------|-----------|-----|
| Spoke/Slice with supervisor | `src/my_slice/my_slice_sup.erl` + `my_slice.erl` | Every spoke has its own supervisor. Domain sup → spoke sups → workers. |
| Listener as a slice | `src/follower_events_listener/follower_events_listener_sup.erl` | Listeners are spokes. They get directories AND supervisors. |
| Command slice | `src/record_follower/record_follower_v1.erl` + `maybe_record_follower.erl` | Commands are spokes. Co-locate command, event, handler. |
| Domain owns its spokes | `manage_social_sup` → `follower_events_listener_sup` | Domain supervisor supervises spoke supervisors, NOT workers directly. |
| Domain starts its own store | `manage_X_sup:init/1` calls `reckon_db_sup:start_store/1` | Each domain owns its event store. Store config is in the domain, not sys.config. |

**Supervision hierarchy:**
```
Domain Supervisor (manage_social_sup)
├── Spoke Supervisor (follower_events_listener_sup)
│   └── follower_events_listener (worker)
├── Spoke Supervisor (endorsement_events_listener_sup)
│   └── endorsement_events_listener (worker)
├── Spoke Supervisor (record_follower_sup) [if needed]
│   └── ... workers
└── ... other spokes
```

**This is WHY slices need directories** — they contain both supervisor AND worker(s).

---

## Project Overview

**macula-hecate** is a lightweight Erlang daemon that connects AI agents to the Macula mesh network. It's designed to run as a sidecar alongside any agent, exposing a simple REST API for mesh operations.

## Naming Conventions (STRICT)

### Event and Command Type Format

**Commands and event types, when represented as strings (binaries), MUST be snake_case_vN:**

```erlang
%% ✅ CORRECT
event_type => <<"rpc_call_tracked_v1">>
event_type => <<"capability_announced_v1">>
command_type => <<"announce_capability_v1">>

%% ❌ WRONG - No PascalCase, no dots
event_type => <<"RpcCallTracked.v1">>     % Wrong: PascalCase + dot separator
event_type => <<"RpcCallTrackedV1">>      % Wrong: PascalCase
event_type => rpc_call_tracked_v1         % Wrong: atom (use binary)
```

**Rule:** Follow Erlang conventions - modules are snake_case, event type binaries are snake_case, records are snake_case. No .NET-style PascalCase.

## Architecture

```
Agent (any runtime)
    ↓ REST API (:4444)
hecate (Erlang daemon)
    ↓ HTTP/3 (QUIC)
Macula Mesh
```

### CQRS Architecture with Embedded ReckonDB

**CRITICAL: ReckonDB/Evoq Integration Pattern**

Each domain follows strict CQRS separation:

**Command Services (e.g., `manage_capabilities`):**
- Each command service gets its **own embedded ReckonDB instance**
- Uses `reckon_evoq` for command dispatching
- Uses `reckon_db` (embedded mode) for local event storage
- Optionally can include projections (see note below)

**Query Services (e.g., `query_capabilities`):**
- Use `reckon_evoq` to subscribe to events from command services
- Projections consume events and update SQLite read models
- **Do NOT** need their own ReckonDB instance (they subscribe to command service events)

**Architecture Note: Projections and Event Schemas**

**For Hecate (multi-domain system with 6+ domains): Use separate query services.**

Event schemas are **published contracts** owned by the command service that produces them. Query services depend on command services to access event types for projections.

**Recommended Structure:**
```
apps/manage_capabilities/     # Command service (producer)
├── src/
│   ├── announce_capability/
│   │   ├── announce_capability_v1.erl      # Command
│   │   ├── capability_announced_v1.erl     # Event (PUBLISHED CONTRACT)
│   │   ├── maybe_announce_capability.erl   # Handler
│   │   └── capability_aggregate.erl        # Aggregate
│   └── manage_capabilities_sup.erl
└── manage_capabilities.app.src

apps/query_capabilities/      # Query service (consumer)
├── src/
│   ├── projections/
│   │   └── capability_announced_v1_to_capabilities.erl  # Projection
│   ├── queries/
│   │   ├── find_capability.erl
│   │   └── list_capabilities.erl
│   └── query_capabilities_sup.erl
├── query_capabilities.app.src
└── rebar.config  # Depends on manage_capabilities for event schemas
```

**Query Service Dependency:**
```erlang
%% apps/query_capabilities/rebar.config
{deps, [
    {manage_capabilities, {path, "../manage_capabilities"}}  % Access event schemas
]}.
```

**Why This Works:**
- **Natural dependency direction**: Query services consume events from command services (query → command)
- **Clear ownership**: Command service owns events (it produces them), query service uses them
- **Scalability**: Multiple query services can depend on same command service for different read models
- **Standard CQRS**: Matches patterns from Event Store, Axon Framework, Commanded

**When to Co-locate Projections (NOT recommended for Hecate):**

Only co-locate projections in the command service for:
- **Trivial domains** with 1-2 simple projections
- **Proof-of-concept** or prototype code
- **Single read model** that exactly mirrors the write model

For production systems with:
- Complex queries (search, filtering, aggregations)
- Multiple read models from same events
- Independent query service scaling

→ **Always use separate query services.**

**Why NOT Create Separate Schema Libraries:**

Avoid creating `manage_capabilities_schemas` libraries unless:
- Events are shared across **multiple command services** (rare - usually indicates poor boundaries)
- You need **complex cross-service schema versioning**

For typical bounded contexts, the overhead (3 apps per domain) isn't justified.

**Example Supervisor Pattern (Command Service):**

```erlang
%% apps/manage_capabilities/src/manage_capabilities_sup.erl
init([]) ->
    Children = [
        %% Embedded ReckonDB instance
        {reckon_db,
            {reckon_db, start_link, [#{name => manage_capabilities_db}]},
            permanent, 5000, worker, [reckon_db]},

        %% Evoq command dispatcher
        {evoq_dispatcher,
            {evoq, start_link, [#{store => manage_capabilities_db}]},
            permanent, 5000, worker, [evoq]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
```

### Event Structure and Envelope

**CRITICAL: Understanding how your business events fit into evoq's event envelope**

#### The evoq_event Envelope

All events in reckon-db/evoq are wrapped in an `evoq_event` record (from `evoq/include/evoq_types.hrl`):

```erlang
-record(evoq_event, {
    event_id :: binary(),              %% Unique identifier
    event_type :: binary(),            %% e.g., <<"CapabilityAnnounced.v1">>
    stream_id :: binary(),             %% e.g., <<"capability-cap-123">>
    version :: non_neg_integer(),      %% Stream version (0-based)
    data :: map() | binary(),          %% YOUR BUSINESS EVENT PAYLOAD
    metadata :: map(),                 %% Correlation, causation, user context
    tags :: [binary()] | undefined,    %% Cross-stream queries
    timestamp :: integer(),            %% Event creation time
    epoch_us :: integer(),             %% Microsecond timestamp
    data_content_type :: binary(),     %% Default: <<"application/json">>
    metadata_content_type :: binary()  %% Default: <<"application/json">>
}).
```

#### Where Your Business Event Fits

**Your event module (e.g., `capability_announced_v1`) produces the `data` field:**

```erlang
%% capability_announced_v1.erl produces a map for the 'data' field
-module(capability_announced_v1).
-export([new/6, to_map/1, from_map/1]).

%% Internal representation (opaque record)
-record(capability_announced_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    tags :: [binary()],
    description :: binary(),
    demo_procedure :: binary() | undefined,
    metadata :: map()
}).

%% to_map/1 returns JUST the payload (goes into evoq_event.data)
to_map(#capability_announced_v1{...} = Event) ->
    #{
        capability_mri => ...,
        agent_identity => ...,
        tags => ...,
        description => ...,
        demo_procedure => ...,
        metadata => ...
    }.

%% from_map/1 takes JUST the payload (extracted from evoq_event.data)
from_map(#{capability_mri := MRI, ...} = Data) ->
    {ok, #capability_announced_v1{...}}.
```

#### Complete Event Lifecycle Example

**1. Command Dispatched:**
```erlang
%% Handler returns events as maps
{ok, [Event]} = maybe_announce_capability:handle(Cmd),
EventMap = capability_announced_v1:to_map(Event),
%% EventMap = #{capability_mri => ..., agent_identity => ..., ...}
```

**2. Evoq Wraps in Envelope:**
```erlang
%% reckon_evoq automatically creates the envelope
EvqEvent = #evoq_event{
    event_id = <<"evt-uuid-here">>,
    event_type = <<"CapabilityAnnounced.v1">>,  %% Derived from module name
    stream_id = <<"capability-mri:capability:io.macula/weather">>,
    version = 0,
    data = EventMap,  %% YOUR to_map/1 result goes here
    metadata = #{
        correlation_id => <<"req-abc">>,
        causation_id => <<"cmd-xyz">>,
        timestamp => 1703001234567
    },
    tags = [<<"realm:io.macula">>],
    timestamp = 1703001234567,
    epoch_us = 1703001234567000
}.
```

**3. Stored in ReckonDB:**
```erlang
%% Persisted as JSON map in event store
#{
    event_type => <<"CapabilityAnnounced.v1">>,
    data => #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"did:macula:agent123">>,
        tags => [<<"weather">>],
        description => <<"Weather service">>,
        demo_procedure => null,
        metadata => #{}
    },
    metadata => #{
        correlation_id => <<"req-abc">>,
        causation_id => <<"cmd-xyz">>
    },
    tags => [<<"realm:io.macula">>]
}
```

**4. Projection Receives Event:**
```erlang
%% In query service projection
handle_event(#evoq_event{
    event_type = <<"CapabilityAnnounced.v1">>,
    data = EventData,
    metadata = Metadata
}) ->
    %% Deserialize from the 'data' field
    {ok, Event} = capability_announced_v1:from_map(EventData),

    %% Project to read model
    capability_announced_v1_to_capabilities:project(Event, Metadata).
```

#### Event Naming Conventions

| Component | Format | Example |
|-----------|--------|---------|
| **event_type** (binary) | PascalCase past tense | `<<"CapabilityAnnounced.v1">>` |
| **Module name** | snake_case + version | `capability_announced_v1.erl` |
| **Record name** | snake_case + version | `#capability_announced_v1{}` |
| **Stream ID** | `{aggregate}-{id}` | `<<"capability-mri:capability:...">>` |

#### Metadata Standard Fields

Always include in `evoq_event.metadata`:

- `correlation_id` - Links related operations (request ID)
- `causation_id` - What caused this event (command ID)
- `user_id` - Who triggered it (agent identity)
- `realm_id` - Which realm it belongs to
- `timestamp` - When it happened

#### Tags for Cross-Stream Queries

Use `evoq_event.tags` for cross-stream queries:

```erlang
tags => [
    <<"realm:io.macula">>,
    <<"plugin:weather">>,
    <<"agent:did:macula:agent123">>
]
```

#### Event Versioning

Version events in the type name:

```erlang
%% Version 1
event_type => <<"CapabilityAnnounced.v1">>

%% Version 2 (added new fields)
event_type => <<"CapabilityAnnounced.v2">>

%% Handle in projections:
handle_event(#evoq_event{event_type = <<"CapabilityAnnounced.v1">>, data = D}) ->
    upgrade_to_v2(D);
handle_event(#evoq_event{event_type = <<"CapabilityAnnounced.v2">>, data = D}) ->
    process_v2(D).
```

#### Key Takeaways

1. **Your event modules produce/consume ONLY the `data` field**
2. **evoq handles the envelope** (event_id, stream_id, version, timestamps)
3. **Metadata is separate** from your business event data
4. **Tags enable cross-stream queries** (realm, plugin, agent)
5. **Event type is a binary** (not an atom), use version suffix
6. **Stream ID follows convention** `{aggregate_type}-{aggregate_id}`

### Core Modules

| Module | Purpose |
|--------|---------|
| `hecate_app` | OTP application |
| `hecate_sup` | Top-level supervisor |
| `hecate_identity` | MRI + keypair management |
| `hecate_mesh` | Macula mesh connection |
| `hecate_rpc` | RPC client + procedure registry |
| `hecate_pubsub` | Pub/sub handler |
| `hecate_ucan` | UCAN wallet + capability management |
| `hecate_store` | SQLite persistence |
| `hecate_api` | Cowboy REST API |

## Build Commands

```bash
# Fetch dependencies
rebar3 get-deps

# Compile
rebar3 compile

# Run tests
rebar3 eunit
rebar3 ct

# Dialyzer
rebar3 dialyzer

# Build release
rebar3 release

# Run release
_build/default/rel/hecate/bin/hecate foreground

# Build self-contained tarball
rebar3 as prod tar
```

## Directory Structure

```
macula-hecate/
├── src/
│   ├── hecate_app.erl          # Application behaviour
│   ├── hecate_sup.erl          # Top supervisor
│   ├── hecate_identity.erl     # Identity management
│   ├── hecate_mesh.erl         # Mesh connection (gen_server)
│   ├── hecate_rpc.erl          # RPC operations
│   ├── hecate_pubsub.erl       # Pub/sub handling
│   ├── hecate_ucan.erl         # UCAN tokens
│   ├── hecate_store.erl        # SQLite wrapper
│   ├── hecate_cli.erl          # CLI interface
│   └── hecate_api/
│       ├── hecate_api_handler.erl   # Cowboy handler
│       ├── hecate_api_rpc.erl       # /rpc/* endpoints
│       ├── hecate_api_pubsub.erl    # /pubsub/* endpoints
│       ├── hecate_api_ucan.erl      # /ucan/* endpoints
│       └── hecate_api_identity.erl  # /identity endpoint
├── include/
│   └── hecate.hrl              # Common records/macros
├── priv/
│   ├── schema.sql              # SQLite schema
│   └── install.sh              # Installer script
├── test/
│   ├── hecate_identity_tests.erl
│   ├── hecate_rpc_tests.erl
│   └── hecate_api_SUITE.erl
├── config/
│   ├── sys.config              # Release config
│   └── vm.args                 # VM args
├── assets/
│   ├── architecture.svg
│   ├── handshake-flow.svg
│   └── install-flow.svg
├── rebar.config
├── rebar.lock
├── README.md
├── CLAUDE.md
├── CHANGELOG.md
└── LICENSE
```

## Dependencies

```erlang
{deps, [
    %% Macula mesh client
    {macula, "0.20.5"},

    %% HTTP server
    {cowboy, "2.12.0"},

    %% SQLite
    {esqlite, "0.8.8"},

    %% HTTP client
    {hackney, "1.20.1"},

    %% CLI
    {getopt, "1.0.3"}
]}.
```

**Note:** JSON encoding uses OTP's built-in `json` module (OTP 27+), not a third-party library.

## 🔥 MESH INTEGRATION DOCTRINE (NON-NEGOTIABLE)

**The mesh is NOT an event bus. FACTS ≠ EVENTS. Understand this or fail.**

### Key Concepts

| Term | What It Is | Where It Lives |
|------|-----------|----------------|
| **FACT** | External truth published to mesh | Between agents |
| **EVENT** | Internal domain event (what happened) | Within agent |
| **COMMAND** | Intention (what should happen) | Within agent |
| **HOPE** | RPC request (optimistic, we "hope" it executes) | Between agents |
| **FEEDBACK** | RPC response | Between agents |

### Correct Integration Flows

**RECEIVING A FACT (from another agent):**
```
Mesh FACT → LISTENER → converts to → COMMAND → AGGREGATE → DOMAIN EVENT → stored → projected
```

**PUBLISHING A FACT (to other agents):**
```
DOMAIN EVENT → EMITTER → converts to → FACT → Mesh
```

**RPC CALL (calling another agent):**
```
REQUESTER(AgentA) → HOPE → DHT RPC Endpoint (special topic) → RESPONDER(AgentB)
```

**RPC RESPONSE (responding to a call):**
```
RESPONDER(AgentB) → converts HOPE to COMMAND → AGGREGATE → result → FEEDBACK → REQUESTER(AgentA)
```

### The Four Mesh Components

| Component | Purpose |
|-----------|---------|
| **LISTENER** | Receives FACTs from mesh, converts to COMMANDs, dispatches to aggregate |
| **EMITTER** | Converts DOMAIN EVENTs to FACTs, publishes to mesh |
| **REQUESTER** | Sends HOPEs (RPC calls), receives FEEDBACKs |
| **RESPONDER** | Receives HOPEs, dispatches commands, sends FEEDBACKs |

### What NOT To Do

```
❌ WRONG: Mesh "event" → subscriber → directly to projection
❌ WRONG: Domain event → directly published to mesh
❌ WRONG: Treating FACTs as EVENTs
❌ WRONG: Bypassing the command/aggregate layer
```

**The mesh subscriber pattern in this codebase is WRONG.** It shortcuts the command layer and treats external facts as internal events. This must be refactored.

---

## ⚠️ ARCHITECTURAL VIOLATIONS TO FIX (STRICT)

**These violations MUST be corrected. Do NOT replicate these patterns.**

### 1. WRONG: `hecate_mesh_subscriber` Bypasses Command Layer

`apps/hecate_mesh/src/hecate_mesh_subscriber.erl` fundamentally misunderstands mesh integration:
- It subscribes to mesh topics and routes directly to projection modules
- It treats mesh messages as EVENTS instead of FACTS
- It bypasses the COMMAND → AGGREGATE flow entirely

**See MESH INTEGRATION DOCTRINE above.** The correct flow is:
```
Mesh FACT → LISTENER → COMMAND → AGGREGATE → DOMAIN EVENT → stored → projected
```

NOT:
```
Mesh "event" → subscriber → projection (WRONG!)
```

**This module should be replaced with proper LISTENER/EMITTER/REQUESTER/RESPONDER components.**

### 2. Single Source of Truth for Projections

Projections should read from ONE source: the local event store (ReckonDB/Evoq).

- Mesh FACTs → converted to COMMANDs → produce DOMAIN EVENTs → stored in ReckonDB
- Projections subscribe to ReckonDB only

Do NOT have mesh subscribers calling projections directly. The event store is the single source of truth.

### 3. Horizontal Subdirectories in `query_capabilities`

`apps/query_capabilities/src/` has:
- `projections/` ❌
- `queries/` ❌

Other query apps correctly put files flat in `src/`. Do NOT create horizontal subdirectories. Follow the pattern in `query_identities`, `query_social`, etc.

### 4. Duplicate API Files

There are `hecate_api_*.erl` files in BOTH:
- Root `src/` 
- `apps/hecate_api/src/`

**Pick ONE location.** Having duplicates causes confusion and potential conflicts.

---

## Coding Standards

### From Parent CLAUDE.md (apply these):

1. **No Elixir wrappers** — This is pure Erlang
2. **Pattern matching** over case expressions where possible
3. **Vertical slicing** — Each module is a capability, not a layer
4. **Business events** — No CRUD naming
5. **Deep-study deps** — Read macula source before using

### Erlang Style

```erlang
%% ✅ Good: Pattern matching on function heads
handle_call({register, Name, Endpoint}, _From, State) ->
    %% ...
handle_call({unregister, Name}, _From, State) ->
    %% ...

%% ❌ Bad: case inside function
handle_call(Msg, _From, State) ->
    case Msg of
        {register, Name, Endpoint} -> %% ...
        {unregister, Name} -> %% ...
    end.
```

### Supervision Tree

```
hecate_sup (one_for_one)
├── hecate_store (worker)          # Must start first
├── hecate_identity (worker)       # Depends on store
├── hecate_mesh (worker)           # Depends on identity
├── hecate_rpc (worker)            # Depends on mesh
├── hecate_pubsub (worker)         # Depends on mesh
├── hecate_ucan (worker)           # Depends on store
└── hecate_api_sup (supervisor)    # Cowboy
    └── cowboy listeners
```

## API Design

REST API follows these conventions:

```
POST   /rpc/call              → Call remote procedure
POST   /rpc/register          → Register local procedure
DELETE /rpc/register/{name}   → Unregister procedure
GET    /rpc/procedures        → List procedures

POST   /pubsub/subscribe      → Subscribe to topic
DELETE /pubsub/subscribe      → Unsubscribe
POST   /pubsub/publish        → Publish to topic
GET    /pubsub/messages       → Poll messages

POST   /ucan/grant            → Grant capability
DELETE /ucan/revoke/{id}      → Revoke capability
GET    /ucan/capabilities     → List capabilities

GET    /identity              → Get current identity
GET    /health                → Health check
```

All responses are JSON:
```json
{"ok": true, "result": {...}}
{"ok": false, "error": "description"}
```

## Event Sourcing

All significant operations are logged as events in SQLite:

```sql
CREATE TABLE events (
    id INTEGER PRIMARY KEY,
    stream_id TEXT NOT NULL,
    type TEXT NOT NULL,
    data BLOB NOT NULL,
    metadata BLOB,
    created_at INTEGER NOT NULL
);
```

Event types:
- `identity_created`
- `procedure_registered`
- `procedure_unregistered`
- `capability_granted`
- `capability_revoked`
- `rpc_called`
- `rpc_received`
- `message_published`
- `message_received`

## CLI Implementation

Use `escript` for CLI:

```erlang
%% hecate_cli.erl
main(["init" | Args]) -> init(Args);
main(["start" | Args]) -> start(Args);
main(["stop"]) -> stop();
main(["status"]) -> status();
main(["call", Proc | Args]) -> call(Proc, Args);
main(_) -> usage().
```

## Release Configuration

`config/sys.config`:
```erlang
[
    {hecate, [
        {api_port, 4444},
        {api_host, {127, 0, 0, 1}},
        {data_dir, "~/.hecate"},
        {bootstrap, ["boot.macula.io:4433"]},
        {realm, <<"io.macula">>}
    ]},
    {kernel, [
        {logger_level, info}
    ]}
].
```

## Testing Strategy

1. **Unit tests** (`eunit`): Individual module functions
2. **Integration tests** (`ct`): API endpoints, mesh connection
3. **Property tests** (`proper`): UCAN token generation/validation

```bash
rebar3 eunit                    # Unit tests
rebar3 ct                       # Common Test
rebar3 proper                   # Property tests
rebar3 cover                    # Coverage report
```

## Installer Script

`priv/install.sh`:
```bash
#!/bin/bash
set -euo pipefail

REPO="macula-io/macula-hecate"
INSTALL_DIR="${HOME}/.local/bin"
DATA_DIR="${HOME}/.hecate"

# Detect OS/arch
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
esac

# Download
VERSION=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep tag_name | cut -d '"' -f 4)
URL="https://github.com/${REPO}/releases/download/${VERSION}/hecate-${OS}-${ARCH}.tar.gz"

echo "Installing hecate ${VERSION}..."
mkdir -p "$INSTALL_DIR" "$DATA_DIR"
curl -sL "$URL" | tar xz -C "$INSTALL_DIR"
chmod +x "${INSTALL_DIR}/hecate"

echo "✅ Installed to ${INSTALL_DIR}/hecate"
echo "Run: hecate init"
```

## Deployment

### GitHub Actions

```yaml
name: Release
on:
  push:
    tags: ['v*']

jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        include:
          - os: ubuntu-latest
            target: linux-amd64
          - os: macos-latest
            target: darwin-arm64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: '26'
          rebar3-version: '3.22'
      - run: rebar3 as prod tar
      - run: mv _build/prod/rel/hecate/*.tar.gz hecate-${{ matrix.target }}.tar.gz
      - uses: softprops/action-gh-release@v1
        with:
          files: hecate-*.tar.gz
```

## Questions to Resolve

1. **SQLite vs ETS** — SQLite for persistence, ETS for runtime cache?
2. **Daemon management** — Use systemd unit file or keep self-contained?
3. **Hot upgrades** — Support relup for in-place updates?
4. **Metrics** — Expose Prometheus metrics?

---

*Remember: This is a daemon for agents, not humans. Optimize for API usability, not CLI polish.*

---

## Support

If you find this project valuable, consider supporting its development:

**☕ Buy Me a Coffee:** https://buymeacoffee.com/rlefever

