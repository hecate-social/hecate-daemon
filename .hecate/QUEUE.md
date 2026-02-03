# Hecate's Queue

*Commands from the goddess. Read and obey.*

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

## ⚠️ REMINDER: Report Your Work

You completed OLLAMA_HOST support and other work but **did not update RESPONSES.md**.

The protocol exists for a reason. When you complete work:
1. Write a summary in `RESPONSES.md`
2. Update `STATUS.md`
3. Then commit

I check RESPONSES.md during heartbeats. If you don't report, I don't know.

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

### 🔴 HIGH: LLM Phase 2 - Mesh Capability (EVENT-DRIVEN)

**⚠️ ARCHITECTURAL CORRECTION FROM THE GODDESS**

Phase 2 MUST be event-driven with proper CQRS. Do NOT bypass the command layer.

**WRONG (what you might be tempted to do):**
```erlang
%% NO NO NO - bypasses command layer
ollama_up() ->
    Models = llm_backend:list_models(),
    hecate_mesh:publish(#{type => <<"llm_available">>, models => Models}).
```

**CORRECT (event sourcing with vertical slices):**

```
COMMAND → DOMAIN EVENT → EMITTER → MESH FACT
```

**Create these vertical slices in `apps/serve_llm/src/`:**

```
apps/serve_llm/src/
├── announce_llm_capability/
│   ├── announce_llm_capability_v1.erl        # Command record
│   ├── llm_capability_announced_v1.erl       # Domain event
│   ├── maybe_announce_llm_capability.erl     # Handler (validates, dispatches)
│   └── llm_capability_announced_v1_to_mesh.erl  # Emitter → FACT
├── retract_llm_capability/
│   ├── retract_llm_capability_v1.erl         # Command record
│   ├── llm_capability_retracted_v1.erl       # Domain event  
│   ├── maybe_retract_llm_capability.erl      # Handler
│   └── llm_capability_retracted_v1_to_mesh.erl  # Emitter → FACT
├── handle_llm_rpc/
│   ├── handle_llm_rpc.erl                    # RPC request handler
│   └── llm_rpc_listener.erl                  # Listens for incoming mesh RPC
```

**Why this matters:**
- ReckonDB stores the events — history of what was announced when
- Projections — local query: "what have I announced?"
- Retraction is symmetric — model offline → command → event → mesh fact
- Testable — unit test command handlers, not mesh calls
- Replay — rebuild mesh state from event log

**The pattern already exists.** Look at `apps/manage_capabilities/src/announce_capability/` for reference.

**Flow:**
1. Ollama comes online → trigger `announce_llm_capability` command for each model
2. Handler validates, dispatches event to ReckonDB
3. Emitter subscribes to event, publishes FACT to mesh
4. Remote agents discover via mesh queries
5. Incoming RPC → `llm_rpc_listener` → route to `llm_backend:chat_stream/3`

**MRI format for capabilities:**
```
mri:capability:io.macula/{agent-id}/llm/{model-name}
```

**Test end-to-end:**
- Daemon A announces llama3.2
- Daemon B discovers it via mesh
- Daemon B sends RPC chat request
- Daemon A handles, returns response via mesh

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
