# Plan: LLM Capability Service

**Goal:** Daemon can serve a local LLM to the mesh as a discoverable capability.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                 hecate-daemon                    │
│                                                 │
│  ┌─────────────┐      ┌──────────────────────┐  │
│  │  serve_llm  │      │     hecate_api       │  │
│  │             │      │                      │  │
│  │  backend ───┼──────┼─► POST /api/llm/chat │  │
│  │      │      │      │   (local requests)   │  │
│  │      ▼      │      └──────────────────────┘  │
│  │  Ollama     │                                │
│  │  :11434     │      ┌──────────────────────┐  │
│  │             │      │    hecate_mesh       │  │
│  │  announce ──┼──────┼─► capability FACT    │  │
│  │             │      │                      │  │
│  │  rpc_handler◄──────┼── incoming RPC       │  │
│  └─────────────┘      └──────────────────────┘  │
└─────────────────────────────────────────────────┘
```

---

## Vertical Slice Structure

```
apps/serve_llm/
├── src/
│   ├── serve_llm_app.erl
│   ├── serve_llm_sup.erl
│   │
│   ├── configure_backend/
│   │   ├── configure_backend_v1.erl       # Command
│   │   ├── backend_configured_v1.erl      # Event  
│   │   └── maybe_configure_backend.erl    # Handler
│   │
│   ├── announce_model/
│   │   ├── announce_model_v1.erl          # Command
│   │   ├── model_announced_v1.erl         # Event
│   │   ├── maybe_announce_model.erl       # Handler
│   │   └── model_announced_v1_to_mesh.erl # Emitter
│   │
│   ├── retract_model/
│   │   └── ...
│   │
│   ├── llm_backend/
│   │   └── llm_backend.erl                # Ollama/llama.cpp client
│   │
│   └── llm_rpc_handler/
│       └── llm_rpc_handler.erl            # Mesh RPC responder
│
├── rebar.config
└── src/serve_llm.app.src
```

---

## Capability MRI

```
mri:capability:io.macula/{agent-id}/llm/{model-name}

# Examples:
mri:capability:io.macula/hecate-dev/llm/llama3.2
mri:capability:io.macula/hecate-dev/llm/qwen2.5-coder
mri:capability:io.macula/hecate-dev/llm/deepseek-r1
```

---

## Backend Interface

```erlang
%% llm_backend.erl - Talks to local inference server

-module(llm_backend).
-export([chat/3, list_models/1, health/1]).

-type backend_config() :: #{
    type := ollama | llamacpp | openai_compat,
    base_url := binary(),  % "http://localhost:11434"
    api_key => binary()    % optional
}.

-type message() :: #{
    role := system | user | assistant,
    content := binary()
}.

-type chat_opts() :: #{
    model := binary(),
    stream => boolean(),
    temperature => float(),
    max_tokens => integer()
}.

%% Synchronous chat completion
-spec chat(backend_config(), [message()], chat_opts()) -> 
    {ok, binary()} | {error, term()}.

%% Streaming chat - sends chunks to caller
-spec chat_stream(backend_config(), [message()], chat_opts(), pid()) -> 
    ok | {error, term()}.

%% List available models from backend
-spec list_models(backend_config()) -> {ok, [binary()]} | {error, term()}.

%% Health check
-spec health(backend_config()) -> ok | {error, term()}.
```

---

## RPC Protocol

Request (over mesh):
```json
{
  "jsonrpc": "2.0",
  "method": "llm.chat",
  "params": {
    "model": "llama3.2",
    "messages": [
      {"role": "system", "content": "You are helpful."},
      {"role": "user", "content": "Hello!"}
    ],
    "stream": true
  },
  "id": "req-123"
}
```

Response (streaming, multiple):
```json
{"jsonrpc": "2.0", "result": {"delta": "Hello"}, "id": "req-123"}
{"jsonrpc": "2.0", "result": {"delta": "!"}, "id": "req-123"}
{"jsonrpc": "2.0", "result": {"delta": " How"}, "id": "req-123"}
{"jsonrpc": "2.0", "result": {"done": true, "usage": {"prompt_tokens": 12, "completion_tokens": 8}}, "id": "req-123"}
```

---

## API Endpoints (Local)

For TUI connecting to local daemon:

```
GET  /api/llm/models          # List models this daemon can serve
POST /api/llm/chat            # Chat completion (same format as RPC)
GET  /api/llm/health          # Backend health check
```

---

## Config (sys.config)

```erlang
{serve_llm, [
    {enabled, true},
    {backend, #{
        type => ollama,
        base_url => <<"http://localhost:11434">>
    }},
    {models, [
        #{name => <<"llama3.2">>, announce => true},
        #{name => <<"qwen2.5-coder">>, announce => true}
    ]},
    {max_concurrent, 2},
    {default_max_tokens, 4096}
]}
```

---

## Phases

### Phase 1: Backend Client
- [ ] `llm_backend.erl` - Ollama HTTP client
- [ ] `chat/3`, `chat_stream/4`, `list_models/1`
- [ ] Health checks

### Phase 2: Local API
- [ ] `hecate_api_llm.erl` - REST endpoints
- [ ] `/api/llm/models`, `/api/llm/chat`
- [ ] Streaming via SSE or chunked response

### Phase 3: Mesh Capability
- [ ] `announce_model/` slice - announce to mesh
- [ ] `llm_rpc_handler/` - respond to mesh RPC
- [ ] Capability format with model metadata

### Phase 4: Discovery
- [ ] Query remote LLM capabilities
- [ ] Route requests to remote daemons
- [ ] Fallback/load balancing (future)

---

## Dependencies

- `hackney` or `httpc` for HTTP client (hackney already in deps)
- No new external deps required

---

*The daemon becomes a gateway to intelligence — local or remote.* 🗝️
