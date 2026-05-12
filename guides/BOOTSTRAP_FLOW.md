# Hecate Daemon Bootstrap Flow

How the daemon starts, connects to the mesh, and becomes operational.

![Bootstrap Flow](assets/bootstrap-flow.svg)

---

## Overview

The hecate daemon is an Erlang/OTP application that connects AI agents to the Macula mesh network. Its startup is a carefully orchestrated sequence that ensures infrastructure is ready before domain services, and domain services are ready before external connections.

**Key principle:** Each domain owns its infrastructure. There is no central store configuration or central supervisor for domain workers. Vertical slicing applies at every level.

---

## Startup Sequence

### Phase 1: Infrastructure (hecate_app:start/2)

The application module starts foundational services in strict order:

```
1. application:ensure_all_started(reckon_db)
   -> Starts reckon_db_sup (supervisor infrastructure)
   -> NO stores created yet

2. application:ensure_all_started(evoq)
   -> CQRS framework loaded
   -> Default adapter: reckon_evoq_adapter

3. hecate_sup:start_link()
   -> Core supervisor starts children
```

ReckonDB provides the event store infrastructure, but individual stores are started later by each domain supervisor in its `init/1`. This follows vertical slicing: domains own their data.

**Source:** `src/hecate_app.erl`

### Phase 2: Core Workers (hecate_sup)

The top-level supervisor starts four permanent workers in order:

```
hecate_sup (one_for_one, intensity=10, period=60)
├── hecate_store      SQLite at ~/.hecate/hecate.db
├── hecate_identity   MRI + Ed25519 keypair
├── hecate_realm_session  Realm join session state machine
└── hecate_ucan       UCAN capability wallet
```

**hecate_store** opens the SQLite database and creates the `kv` and `events` tables if they don't exist. All subsequent modules depend on it for persistence.

**hecate_identity** loads the existing identity from SQLite:
- If found: MRI, realm, and keypair loaded into memory
- If not found: state stays uninitialized (user must call `POST /identity/init`)

**hecate_realm_session** starts in `idle` state, waiting for a join request.

**hecate_ucan** starts the UCAN capability wallet for authorization tokens.

**Source:** `src/hecate_sup.erl`, `src/hecate_identity.erl`, `src/hecate_store.erl`

### Phase 3: Mesh Connection (hecate_mesh)

The mesh app starts a single supervisor with one child:

```
hecate_mesh_sup (one_for_one)
└── hecate_mesh_client
```

On init, `hecate_mesh_client` reads configuration from the `hecate` app (not `hecate_mesh`):

```erlang
Realm     = application:get_env(hecate, realm, <<"io.macula">>),
Bootstrap = application:get_env(hecate, bootstrap, [<<"https://boot.macula.io:4433">>])
```

The daemon's identity is **not** config — it's the keypair held by
`hecate_identity`. `hecate_identity:agent_id/0` returns its current
MRI (anonymous on first boot, then the realm-asserted owner after a
realm join). `hecate_mesh_client` reads it lazily where needed
(`get_status`, `do_join_with_token`), not at `init/1` — the `hecate`
app, which owns `hecate_identity`, starts after `hecate_mesh`.

It then self-sends a `connect` message, deferring the actual connection to `handle_info`. This makes startup **non-blocking** -- other apps continue starting while the mesh connects.

**Connection attempt:**
1. Try each bootstrap URL in order (e.g., `https://boot.macula.io:4433`)
2. Call `macula:connect(Url, #{realm => Realm})`
3. On success: monitor client PID, store in state
4. On failure: retry after 5 seconds

**Reconnection:** If the client process dies, the gen_server receives a `'DOWN'` message, clears subscriptions, and retries after 1 second.

**Source:** `apps/hecate_mesh/src/hecate_mesh_client.erl`

### Phase 4: Domain Services

All umbrella apps start in the order defined in the release config. Each command service follows the same pattern:

**Command services** (`manage_capabilities`, `manage_reputation`, `manage_social`, etc.):
1. Start own ReckonDB store via `reckon_db_sup:start_store/1`
2. Start emitters (subscribe to domain events, publish mesh FACTs)
3. Start process managers (subscribe to cross-domain events, dispatch commands)

**Query services** (`query_capabilities`, `query_reputation`, `query_social`, etc.):
1. Start SQLite read model store
2. Start internal event subscribers (project domain events to SQLite)
3. Start mesh listeners (receive remote FACTs, convert to commands)
4. Start measurement workers (e.g., latency measurement)

**Example: manage_capabilities_sup children:**

```
manage_capabilities_sup (one_for_one)
├── capability_announced_v1_to_mesh      Emitter
├── capability_updated_v1_to_mesh        Emitter
├── capability_retracted_v1_to_mesh      Emitter
├── on_llm_detected_announce_capability  Process Manager
├── on_llm_removed_retract_capability    Process Manager
└── on_llm_status_reported_update_capability  Process Manager
```

**Source:** Each `apps/manage_*/src/manage_*_sup.erl` and `apps/query_*/src/query_*_sup.erl`

### Phase 5: LLM Service + API

**serve_llm** starts its domain workers:
- `detect_llm_models` polls Ollama at `http://localhost:11434` for available models
- `report_llm_status` periodically checks model status (queue depth, availability)
- RPC responders subscribe to mesh topics for remote LLM requests

**hecate_api** starts last, launching Cowboy HTTP listeners on port 4444. At this point all dependencies are running and the API can safely delegate to any module.

**Source:** `apps/serve_llm/src/serve_llm_sup.erl`, `apps/hecate_api/src/hecate_api_app.erl`

---

## Release App Order

The release config in `rebar.config` defines the startup order:

```erlang
{release, {hecate, "0.1.0"}, [
    %% Infrastructure (MUST start first)
    reckon_db, evoq, reckon_evoq,

    %% Mesh (before domains with listeners)
    hecate_mesh,

    %% Command services
    manage_capabilities, manage_reputation, manage_social,
    manage_subscriptions, manage_identities, manage_ucan,

    %% Query services
    query_capabilities, query_reputation, query_social,
    query_subscriptions, query_identities, query_ucan,

    %% Core
    hecate,

    %% LLM + API (last)
    serve_llm, hecate_api, sasl
]}
```

---

## User-Initiated Flows

After startup, the daemon is running but may need user interaction to become fully operational.

### 1. Identity Initialization

If no identity exists in SQLite, it must be created:

```bash
curl -X POST http://localhost:4444/identity/init
```

This triggers:
1. Generate Ed25519 keypair via `crypto:generate_key(eddsa, ed25519)`
2. Build MRI: `mri:agent:{realm}/{owner}/{name}` (e.g., `mri:agent:io.macula/anonymous/hecate-a1b2`)
3. Persist to SQLite in the `identity` bucket
4. Log `identity_created` audit event

The name is auto-generated as `hecate-{4 hex chars}` if not provided.

**Source:** `src/hecate_identity.erl:123-160`

### 2. Join Realm

Joins the daemon with a realm (e.g., macula.io) through an OAuth login flow:

```bash
hecate join
```

Flow:
1. Daemon sends public key + agent MRI to realm API (`POST /api/v1/join/sessions`)
2. Realm returns `session_id` and `join_url`
3. Browser opens the join URL for OAuth login
4. User logs in with GitHub — session auto-confirms on OAuth completion
5. Daemon polls every 2 seconds until confirmed (10 minute TTL)
6. On confirmation: stores `refresh_token`, `org_identity`, and `cert_pem`

**Source:** `src/hecate_realm_session.erl`

### 3. Capability Announcement (Automatic)

Once the daemon is running with an active mesh connection, LLM capabilities are announced automatically:

```
serve_llm polls Ollama (/api/tags)
    ↓
detect_llm_models emits llm_detected_v1 event
    ↓
Process Manager (on_llm_detected_announce_capability)
subscribes to llm_detected_v1 events
    ↓
Dispatches announce_capability_v1 command
with model info + hardware metadata
    ↓
Event stored in ReckonDB
    ↓
Emitter publishes integration FACT to mesh
    ↓
Other agents discover the capability
```

The capability announcement includes:
- **Model info:** name, context_length, quantization, parameter_count, family
- **Hardware info:** ram_gb, cpu_cores, gpu, gpu_vram_gb (from sys.config)
- **Status:** queue_depth, available (updated by periodic heartbeat)

### 4. RPC Serving (Automatic)

Responders subscribe to mesh RPC topics and handle incoming requests:

```
Remote agent sends RPC request to mesh topic
    ↓
Responder receives the request
    ↓
Routes to local backend (e.g., Ollama for LLM chat)
    ↓
Sends response back via mesh
```

---

## Configuration Reference

### sys.config

| Key | App | Default | Purpose |
|-----|-----|---------|---------|
| `api_port` | hecate | 4444 | REST API port |
| `api_host` | hecate | `{127,0,0,1}` | API bind address |
| `data_dir` | hecate | `~/.hecate` | SQLite + data directory |
| `bootstrap` | hecate | `["https://boot.macula.io:4433"]` | Mesh bootstrap servers |
| `realm` | hecate | `<<"io.macula">>` | Realm identifier |
| `managed_identities` | hecate | `[<<"mri:agent:io.macula/hecate-dev">>]` | Child-service MRIs (currently unused — see realm rethink) |
| `hardware` | hecate | `#{...}` | Hardware capabilities |

> The daemon's own identity is **not** config — it's the keypair held by `hecate_identity` (`agent_id/0`). The old `gateway_identity` config string was removed (realm-rethink step 1).
| `ollama_url` | serve_llm | `"http://localhost:11434"` | Ollama API endpoint |
| `poll_interval_ms` | serve_llm | 300000 | Model detection interval (5 min) |
| `status_interval_ms` | serve_llm | 30000 | Status heartbeat interval (30s) |

### vm.args

| Flag | Value | Purpose |
|------|-------|---------|
| `-sname` | hecate | Short node name |
| `-setcookie` | hecate_cookie | Distributed Erlang cookie |
| `-heart` | | Heartbeat monitoring |
| `+A` | 64 | Async I/O threads |
| `+P` | 1048576 | Max processes |
| `+Q` | 65536 | Max ports |

---

## Troubleshooting

**Identity not initialized:**
```
[hecate_identity] No identity found - run 'hecate init' to create one
```
Call `POST /identity/init` or use the TUI to initialize.

**Mesh connection failing:**
```
[hecate_mesh] All bootstrap servers failed, retrying in 5s...
```
Check that `boot.macula.io:4433` is reachable. The daemon retries indefinitely. Domain services continue to operate locally.

**Ollama not responding:**
```
detect_llm_models: Failed to list models: {error, econnrefused}
```
Ensure Ollama is running at the configured URL. The poller retries every `poll_interval_ms`.

**ReckonDB gateway worker crashes:**
```
reckon_db_subscriptions:create_filter function_clause
```
Known issue with reckon_db API compatibility. Supervision restarts the worker. Functionally harmless.
