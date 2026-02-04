# Hecate's Queue

*Commands from the goddess. Read and obey.*

---

## ✅ CONFIRMED: Process Manager Refactor APPROVED

**2026-02-04** — Your DECISION and ANTIPATTERN entries were received and reviewed.

### Process Manager Approach: APPROVED ✅

Your analysis is correct. `serve_llm` should NOT have parallel capability infrastructure.

**Proceed with the refactor:**

1. `serve_llm` emits internal events (`llm_model_detected_v1`, `llm_model_removed_v1`)
2. Process Manager in `manage_capabilities` subscribes and dispatches `announce_capability_v1`
3. Remove duplicate LLM-specific emitters/topics/listeners

### Antipattern Saved: Technical Names ✅

Your antipattern has been saved to `~/work/github.com/ANTIPATTERNS.md`.

**Read it. Don't forget it.** We'll reuse this file across repos.

Rename your slices:
- `poll_llm_models/` → `detect_llm_models/`
- `handle_llm_rpc/` → `listen_for_llm_request/`

### You Are Unblocked

Ship it. 🔥

---

## 📍 CHANNEL TAGGING (NEW RULE — READ THIS)

**Effective immediately:** All RESPONSES.md entries MUST include channel tags.

This is the **[daemon]** channel. When writing to RESPONSES.md:
- Prefix your title: `## 2026-02-03 COMPLETE [daemon]: Task Name`
- Cross-references: `Related: Fixed bug in [macula-realm]`

**All channels:**
- `[daemon]` — hecate-daemon (this repo)
- `[tui]` — hecate-tui
- `[node]` — hecate-node
- `[realm]` — hecate-realm
- `[macula-realm]` — macula-io/macula-realm

**Why:** I monitor multiple repos. Without tags, context is lost. Be explicit.

---

## ⚠️ MANDATORY: Re-read CLAUDE.md NOW

**Before doing anything else this session:**

```bash
cat ~/work/github.com/CLAUDE.md
```

New rules have been added. Pay special attention to:
- **"NEVER DELETE FEATURES"** section
- Read the whole file before editing
- Extend, don't replace

**Acknowledge in RESPONSES.md that you've read it.**

---

## ✅ Your Understanding is VERIFIED

Your Phase 2 understanding is correct. The flow, slices, MRI format — all good.

### Answers to Your Questions (UPDATED):

**Q1: Store — CLARIFICATION (you misunderstood)**

> ⚠️ **TWO DIFFERENT STORES. Don't confuse them.**
>
> | Store | Technology | Purpose | What Goes Here |
> |-------|------------|---------|----------------|
> | **Event Store** | ReckonDB | Immutable event log | `llm_capability_announced_v1`, etc. |
> | **Projection Store** | SQLite | Query-optimized read models | `capabilities` table with `type=llm` |
>
> **KEEP your ReckonDB aggregate** (`serve_llm` aggregate for events).
>
> **Projections SUBSCRIBE to events** and write to `query_capabilities_store` (SQLite).
>
> ```
> announce_llm_capability_v1 (command)
>        ↓
> serve_llm aggregate → ReckonDB (event STORED here)
>        ↓
> llm_capability_announced_v1 (event PUBLISHED)
>        ↓
>        ├── Emitter → Mesh FACT
>        └── Projection → query_capabilities_store (SQLite)
> ```
>
> **DO NOT delete your ReckonDB store.** Just add projections that write to SQLite.

**Q2: Polling — how often to poll Ollama for changes?**

> **On startup + periodic fallback.** Poll on startup to announce all models, then every 5 minutes to catch additions/removals. Also emit `update_llm_status` periodically (every 30s?) to update queue depth and availability.

**Q3: TUI dependency — wait for TUI or proceed?**

> **Proceed.** Don't block on TUI. Ship Phase 2 independently.

### Go Build It

Expanded scope in the Phase 2 section below. Read it carefully — rich metadata, hardware info, our/their distinction. 🔥

---

## Protocol

| File | Your Access |
|------|-------------|
| `QUEUE.md` | **READ-ONLY** |
| `RESPONSES.md` | Write here |
| `STATUS.md` | Update here |

---

## 🔴 HIGH: LLM Capability Service

**TOP PRIORITY. The daemon becomes a gateway to intelligence.**

Read `plans/PLAN_LLM_CAPABILITY.md` for the full design.

**Phase 1: Local Backend + API**

Create `apps/serve_llm/` with vertical slices:

```
apps/serve_llm/src/
├── serve_llm_app.erl
├── serve_llm_sup.erl
├── llm_backend/
│   └── llm_backend.erl       # Ollama HTTP client
└── (mesh capability slices come in Phase 2)
```

**Implement:**
1. `llm_backend.erl` — talk to Ollama at `localhost:11434`
   - `chat/3` — sync completion
   - `chat_stream/4` — streaming to caller pid
   - `list_models/1` — GET /api/tags
   - `health/1` — health check

2. `hecate_api_llm.erl` — REST endpoints
   - `GET /api/llm/models` — list available models
   - `POST /api/llm/chat` — chat completion (SSE streaming)
   - `GET /api/llm/health` — backend status

**Config:**
```erlang
{serve_llm, [
    {backend, ollama},
    {ollama_url, "http://localhost:11434"}
]}
```

**Test with:**
```bash
# Start Ollama with a model first: ollama run llama3.2
curl http://localhost:4444/api/llm/models
curl -X POST http://localhost:4444/api/llm/chat \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2","messages":[{"role":"user","content":"Hello!"}]}'
```

**The TUI is waiting on this.** Coordinate with `hecate-tui/.hecate/QUEUE.md`.

**Phase 2 (after TUI has chat view):** Mesh capability announcement, RPC handler for remote requests.

---

## Active Tasks

### 🔴 HIGH: LLM Phase 2 - Mesh Capability (EVENT-DRIVEN + RICH METADATA)

**⚠️ EXPANDED SCOPE FROM THE GODDESS**

Phase 2 is about **intelligent model discovery**, not just "announce model exists."

---

#### Architecture Clarification: Our vs Their

**Use existing `query_capabilities` — do NOT create `query_llm`.**

| Table | Purpose |
|-------|---------|
| `capabilities` | MY announcements (what I serve) |
| `remote_capabilities` | THEIR announcements (what I discover from mesh) |

LLM capabilities are just capabilities with `type = <<"llm">>` and rich metadata.

---

#### Rich Metadata in Capability FACTS

The MRI is the **identifier**. The FACT payload carries the **metadata**.

```erlang
%% The FACT published to mesh (llm_capability_announced_v1_to_mesh.erl)
#{
    mri => <<"mri:capability:io.macula/hecate-beam00/llm/llama3.1:70b">>,
    type => <<"llm">>,
    
    %% Model info (from Ollama API)
    model => #{
        name => <<"llama3.1:70b">>,
        context_length => 131072,
        quantization => <<"q4_K_M">>,
        parameter_count => <<"70B">>,
        family => <<"llama">>
    },
    
    %% Hardware info (from hecate-node install detection!)
    hardware => #{
        ram_gb => 48,
        cpu_cores => 8,
        gpu => <<"none">>,           % or <<"nvidia_rtx4090">>
        gpu_vram_gb => 0,            % GPU memory if applicable
        storage_path => <<"/bulk0">>
    },
    
    %% Dynamic status (updated periodically via heartbeat FACTs)
    status => #{
        queue_depth => 0,            % requests waiting
        avg_tokens_per_sec => 45.2,  % measured inference speed
        available => true            % model loaded and ready
    },
    
    announced_at => 1738590000
}
```

---

#### Hardware Info: Where Does It Come From?

**The install script already detects hardware!** (`hecate-node/install.sh`)

Store detected hardware in daemon config or identity:
```erlang
%% sys.config or identity store
{hardware, #{
    ram_gb => 48,
    cpu_cores => 8,
    gpu => <<"none">>,
    storage_path => <<"/bulk0">>
}}
```

Read this when announcing capabilities. The `announce_llm_capability` command should include hardware context.

---

#### Network Latency: Measured by Observer

**Latency is NOT announced by the provider.** Each agent measures it themselves.

```sql
-- In query_capabilities remote_capabilities table
ALTER TABLE remote_capabilities ADD COLUMN latency_ms INTEGER;
ALTER TABLE remote_capabilities ADD COLUMN last_latency_check INTEGER;
```

Periodically ping discovered agents, update latency. This enables routing decisions.

---

#### Vertical Slices (Command Side)

```
apps/serve_llm/src/
├── announce_llm_capability/
│   ├── announce_llm_capability_v1.erl        # Command: model, hardware, metadata
│   ├── llm_capability_announced_v1.erl       # Domain event
│   ├── maybe_announce_llm_capability.erl     # Handler (validates, dispatches)
│   └── llm_capability_announced_v1_to_mesh.erl  # Emitter → rich FACT
├── retract_llm_capability/
│   └── ...
├── update_llm_status/                        # For periodic status updates
│   ├── update_llm_status_v1.erl
│   ├── llm_status_updated_v1.erl
│   ├── maybe_update_llm_status.erl
│   └── llm_status_updated_v1_to_mesh.erl     # Heartbeat FACTs
├── handle_llm_rpc/
│   ├── llm_rpc_listener.erl                  # Listens for mesh RPC
│   └── handle_llm_rpc.erl                    # Routes to llm_backend
```

---

#### Projections (Query Side) — in `query_capabilities`

**Extend `query_capabilities`, don't create new app.**

```
apps/query_capabilities/src/
├── llm_capability_announced_v1_to_capabilities.erl  # NEW projection
├── llm_capability_retracted_v1_to_capabilities.erl  # NEW projection
├── llm_status_updated_v1_to_capabilities.erl        # NEW projection
```

These subscribe to serve_llm events and update the capabilities/remote_capabilities tables.

---

#### Model Selection Query Example

```erlang
%% "Find me a code model with <100ms latency and no queue"
query_capabilities:find(#{
    type => <<"llm">>,
    model_family => <<"qwen">>,      % or tags
    max_latency_ms => 100,
    max_queue_depth => 0
})

%% Returns: beam02's qwen2.5-coder capability with full metadata
```

---

#### What This Enables

```
beam00 (48GB) → llama3.1:70b   [queue:0, 45 tok/s, latency:12ms]
beam01 (16GB) → llama3.2:3b    [queue:2, 120 tok/s, latency:8ms]
beam02 (16GB) → qwen2.5-coder  [queue:0, 80 tok/s, latency:15ms]
beam03 (16GB) → deepseek-r1    [queue:1, 60 tok/s, latency:10ms]

Request: "I need code help, fast"
→ Routes to beam02 (coder model, no queue, good speed)

Request: "Analyze this 50k token document"  
→ Routes to beam00 (only one with 128k context)
```

---

#### Flow Summary

1. Daemon starts → reads hardware config
2. Polls Ollama → gets model list with metadata
3. For each model: `announce_llm_capability` command with model + hardware
4. Event stored in ReckonDB
5. Emitter publishes rich FACT to mesh
6. Other agents discover, store in `remote_capabilities`, measure latency
7. Periodic `update_llm_status` commands for queue depth, availability
8. Incoming RPC → `llm_rpc_listener` → `llm_backend` → response

---

#### Test Scenario

```
# Daemon A (beam00, 48GB)
- Announces llama3.1:70b with hardware metadata

# Daemon B (beam01, 16GB)  
- Discovers beam00's capability via mesh
- Measures latency: 12ms
- Stores in remote_capabilities

# User on B wants to use 70b model
- Query: find llm capability with 70B params
- Result: beam00's llama3.1:70b
- RPC to beam00 → response streams back
```

### 🟢 LOW: Bootstrap Flow Documentation

Document the WORKING flow now that mesh and pairing exist:

1. `hecate init` → Generate keypair, create MRI
2. `hecate start` → Start daemon on :4444
3. TUI pairing flow → Pair with realm
4. Announce capabilities
5. Start serving RPC

---

## Completed Tasks

### ✅ Mesh Connection
- QUIC connection to `boot.macula.io:443` working
- `macula:connect/2` implemented in `hecate_mesh_client.erl`

### ✅ Pairing API (Daemon Side)
- `POST /api/pairing/start` ✓
- `GET /api/pairing/status` ✓
- `POST /api/pairing/cancel` ✓
- End-to-end tested with realm

### ✅ Mesh Integration Refactor (Phases 1-6)
### ✅ Dialyzer Cleanup
### ✅ Codebase Verification (61 tests pass)
### ✅ v0.1.1 Self-Extracting Release
### ✅ Identity Init API (`/api/identity/init`)

---

*Ship it.* 🔥🗝️🔥
