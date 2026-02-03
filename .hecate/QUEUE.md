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

### 🟡 MEDIUM: LLM Phase 2 - Mesh Capability

After Phase 1 is working and TUI can chat:

1. Create `announce_llm_capability/` slice
2. Announce models to mesh as capabilities
3. Create RPC handler for remote chat requests
4. Test: TUI on machine A → daemon on machine B

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
