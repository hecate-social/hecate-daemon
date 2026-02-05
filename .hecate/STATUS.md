# Apprentice Status

*Current state of the apprentice's work.*

---

## Current Task

**COMPLETE: Connector Architecture — manage_connectors Domain + Socket Listeners**

## Last Active

**2026-02-05** — Implemented full connector architecture (Phases 1-3): manage_connectors domain, socket listener process manager, connector API, default TUI connector auto-registration

## Session Log

### 2026-02-05 Session (Connector Architecture — Phases 1-3)

**Status:** Complete

**Completed:**
- **Phase 1: Route Extraction + manage_connectors Domain**
  - Extracted 60+ route dispatch table from `hecate_api_app.erl` into `hecate_api_routes.erl`
  - Created full `apps/manage_connectors/` domain with 4 spokes:
    - `register_connector/` — command, event, handler (computes socket path)
    - `revoke_connector/` — command, event, handler
    - `activate_connector/` — command, event, handler
    - `suspend_connector/` — command, event, handler
  - `connector_aggregate.erl` with bit flags (REGISTERED=1, ACTIVE=2, SUSPENDED=4, REVOKED=8)
  - `manage_connectors_sup.erl` — ReckonDB store init + stale socket cleanup on startup

- **Phase 2: Socket Listener Process Manager**
  - `on_connector_registered_start_listener.erl` — gen_server subscribing to connector events
  - Starts Cowboy listeners on Unix sockets via `{ifaddr, {local, SocketPath}}`
  - Handles all 4 event types (register→start, revoke→stop+delete, suspend→stop, activate→restart)
  - Socket permissions set to 0600
  - `connector_scope_middleware.erl` — Cowboy middleware for route prefix checking

- **Phase 3: Connector API + Default TUI Connector**
  - `hecate_api_connectors.erl` — REST handler for connector management endpoints
  - Routes: POST /connectors/register, GET /connectors, GET /connectors/:id, POST /connectors/:id/revoke
  - Auto-register default "tui" connector on daemon startup
  - TCP listener now opt-in via config `{tcp_listener, true}`
  - Updated sys.config with manage_connectors section
  - Updated root rebar.config with manage_connectors in release

**Verification:**
- `rebar3 compile` ✅ (all 18 apps)

**Files Created:**
- `apps/hecate_api/src/hecate_api_routes.erl`
- `apps/hecate_api/src/hecate_api_connectors.erl`
- `apps/manage_connectors/` — entire directory (17 files)

**Files Modified:**
- `apps/hecate_api/src/hecate_api_app.erl` — uses routes module, TCP opt-in, auto-register
- `apps/hecate_api/rebar.config` — depends on manage_connectors
- `config/sys.config` — manage_connectors config
- `rebar.config` — manage_connectors in release

---

### 2026-02-04 Session (8 Next Steps)

**Status:** Complete

**Completed:**
- Task #73: Rich metadata in capability announcements (hardware + model info)
- Task #74: LLM status heartbeat (report_llm_status gen_server)
- Task #75: Latency measurement for remote capabilities (measure_remote_latency)
- Task #76: Test coverage for new modules (61 → 72 tests)
- Task #77: Wire mesh RPC responders (already wired — verified)
- Task #78: Implement hecate_mesh facade TODOs (subscribe/2, unsubscribe/1)
- Task #79: UCAN validation (MRI validation, authority checks, 13 new tests → 85 total)
- Task #80: Bootstrap flow documentation (guide + SVG diagram)

**Verification:**
- `rebar3 eunit` 85 tests passed
- `rebar3 dialyzer` Clean (fixed 2 warnings in UCAN modules)

**Files Created:**
- `apps/serve_llm/src/report_llm_status/report_llm_status.erl`
- `apps/serve_llm/src/report_llm_status/llm_status_reported_v1.erl`
- `apps/manage_capabilities/src/on_llm_status_reported_update_capability/on_llm_status_reported_update_capability.erl`
- `apps/query_capabilities/src/measure_remote_latency/measure_remote_latency.erl`
- `apps/serve_llm/test/llm_events_test.erl`
- `apps/serve_llm/test/chat_to_llm_test.erl`
- `apps/manage_capabilities/test/process_manager_test.erl`
- `apps/manage_ucan/test/ucan_validation_test.erl`
- `guides/BOOTSTRAP_FLOW.md`
- `assets/bootstrap-flow.svg`

---

### 2026-02-04 Session (serve_llm Refactor)

**Status:** Complete

**Completed:**
- Refactored `serve_llm` to proper Cartwheel architecture:
  - `detect_llms/` — polls Ollama, emits detection events
  - `chat_to_llm/` — handles chat requests with responder
  - `list_available_llms/` — handles list requests with responder
  - `check_llm_health/` — handles health requests with responder
- Created Process Managers in `manage_capabilities`:
  - `on_llm_detected_announce_capability/` — subscribes to llm_detected_v1, dispatches announce_capability_v1
  - `on_llm_removed_retract_capability/` — subscribes to llm_removed_v1, dispatches retract_capability_v1
- Eliminated `hecate_mesh_publisher` (horizontal god module):
  - Refactored all 11 emitters to call `hecate_mesh_client:publish/2` directly
- Removed LLM-specific projections from `query_capabilities` (use generic capability projections)
- Updated `hecate_api_llm.erl` to use new module names
- Fixed obsolete tests and dialyzer warnings

**Verification:**
- `rebar3 eunit` ✅ **61 tests passed**
- `rebar3 dialyzer` ✅ **Clean**

**Files Created:**
- `apps/serve_llm/src/detect_llms/{detect_llms,llm_detected_v1,llm_removed_v1}.erl`
- `apps/serve_llm/src/chat_to_llm/{chat_to_llm,chat_to_llm_responder}.erl`
- `apps/serve_llm/src/list_available_llms/{list_available_llms,list_available_llms_responder}.erl`
- `apps/serve_llm/src/check_llm_health/{check_llm_health,check_llm_health_responder}.erl`
- `apps/manage_capabilities/src/on_llm_detected_announce_capability/on_llm_detected_announce_capability.erl`
- `apps/manage_capabilities/src/on_llm_removed_retract_capability/on_llm_removed_retract_capability.erl`

**Files Deleted:**
- `apps/hecate_mesh/src/hecate_mesh_publisher.erl` (horizontal dispatcher)
- `apps/query_capabilities/src/llm_capability_*.erl` (LLM-specific projections)
- `apps/serve_llm/test/{handle_llm_rpc_tests,llm_backend_tests}.erl` (obsolete)

---

*(Append entries when starting/ending sessions)*

### 2026-02-03 Session (LLM Service - Phase 3)

**Status:** Complete

**Completed:**
- Created `handle_llm_rpc/` vertical slice:
  - `llm_rpc_listener.erl` — Subscribes to `hecate.llm.rpc.{agent-path}` topic
  - `handle_llm_rpc.erl` — Routes chat/list_models/health actions to llm_backend
- Updated `serve_llm_sup.erl` to start the RPC listener
- Sends responses back to requester via mesh reply_to topic

**Commit:** `3a8278f` - feat(serve_llm): Add RPC listener for incoming mesh requests (Phase 3)

**Flow:**
1. Other agent sends HOPE to `hecate.llm.rpc.{this-agent}` topic
2. `llm_rpc_listener` receives request, spawns handler
3. `handle_llm_rpc` routes to `llm_backend` based on action
4. Response published to `reply_to` topic from request

---

### 2026-02-03 Session (LLM Service - Phase 2)

**Status:** Complete

**Completed:**
- Created 3 vertical slices for LLM capability events:
  - `announce_llm_capability/` — command, event, handler, emitter (4 files)
  - `retract_llm_capability/` — command, event, handler, emitter (4 files)
  - `poll_llm_models/` — model poller (1 file)
- Updated `serve_llm_sup.erl` to start:
  - `serve_llm_store` (ReckonDB instance for this domain)
  - `llm_capability_announced_v1_to_mesh` (emitter)
  - `llm_capability_retracted_v1_to_mesh` (emitter)
  - `llm_model_poller` (polls Ollama every 5 min)
- Updated `hecate_mesh_publisher.erl` with LLM event type mappings
- Updated `serve_llm/rebar.config` with src_dirs for slices
- All tests pass, dialyzer clean

**Commit:** `6e40a5b` - feat(serve_llm): Implement Phase 2 - mesh capability announcement

**Flow:**
1. `llm_model_poller` polls Ollama on startup + every 5 min
2. New models → dispatch `announce_llm_capability_v1` command
3. Removed models → dispatch `retract_llm_capability_v1` command
4. Events stored in `serve_llm_store` via evoq
5. Emitters subscribe to events, publish FACTs to mesh

---

### 2026-02-03 Session (LLM Service - Phase 1)

**Status:** Complete (Phase 1)

**Completed:**
- Created `apps/serve_llm/` OTP application:
  - `serve_llm_app.erl`: Application behaviour (can be disabled via config)
  - `serve_llm_sup.erl`: Supervisor
  - `llm_backend/llm_backend.erl`: Ollama HTTP client
    - `chat/2,3`: Synchronous completion
    - `chat_stream/3`: Streaming via message passing
    - `list_models/0,1`: List available models
    - `health/0,1`: Backend health check
- Created REST endpoints in `hecate_api_llm.erl`:
  - `GET /api/llm/models`: List models
  - `POST /api/llm/chat`: Chat completion (SSE streaming supported)
  - `GET /api/llm/health`: Backend status
- Updated `sys.config` with serve_llm configuration
- Updated `rebar.config` release apps
- All tests pass (61)
- Dialyzer clean

**Commit:** `d604efb` - feat: Add serve_llm app with Ollama backend (Phase 1)

---

### 2026-02-03 Session (Earlier)

**Status:** Complete

**Completed:**
- Fixed `query_capabilities_app.erl` - removed call to non-existent `reckon_evoq:subscribe/3`
- Deleted redundant `query_capabilities_projections.erl` - subscriber handles projections
- Verified release starts cleanly:
  - All 6 manage services ✅
  - All 6 query services ✅
  - hecate_api listening on :4444 ✅
  - Mesh connection to boot.macula.io:443 ✅
  - Clean shutdown on SIGTERM ✅

**Non-blocking issues (known):**
- `reckon_db_subscriptions:create_filter` function_clause errors (gateway workers crash/restart)
- These are API compatibility issues with reckon_db, not blocking app startup

---

### 2026-02-02 Session

**Started:** ~02:00 UTC
**Status:** Active

**Completed:**
- Created Cartwheel Architecture educational guides (4 files)
- Created animated SVG diagrams (5 files)
- Created initial `PLAN_MESH_INTEGRATION_REFACTOR.md`
- Read QUEUE.md and APPRENTICE_INSTRUCTIONS.md
- Updated plan with corrected mental model (Gateway, not sidecar)
- **Phase 1a:** Flattened `query_capabilities/src/` structure
- **Phase 1b:** Consolidated duplicate API files
- **Phase 1c:** Converted 11 query modules to vertical slice directories
- **Phase 2:** Added 7 remote tables for mesh fact data
- **Phase 3:** Created 10 new command slices (30 files) for incoming mesh facts

**Phase 4 Completed (with correction):**
- ⚠️ CORRECTED: Initially created horizontal `hecate_mesh_listeners_sup.erl` — WRONG!
- **Fixed:** Each listener now belongs to its **domain supervisor** (vertical slicing)
- Discovery listeners added to query services:
  - `query_capabilities_sup` → `remote_capabilities_listener`
  - `query_identities_sup` → `remote_identities_listener`
- Filtered listeners added to manage services:
  - `manage_social_sup` → `follower_events_listener`, `endorsement_events_listener`
  - `manage_subscriptions_sup` → `subscriber_events_listener`
  - `manage_reputation_sup` → `dispute_events_listener`
  - `manage_ucan_sup` → `ucan_events_listener` (SECURITY-CRITICAL)
- Deleted `hecate_mesh_subscriber.erl` (the wrong god module)
- Deleted `apps/hecate_mesh/src/listeners/` directory (horizontal thinking)

**Phase 5 Completed:**
- ⚠️ CORRECTED: Original plan suggested horizontal `hecate_mesh/src/emitters/` — WRONG!
- **Emitters are already in correct locations** (in their command slices)
- Added missing emitters to domain supervisors:
  - `manage_social_sup` — added 3 missing emitters
  - `manage_identities_sup` — added 1 missing emitter

**Phase 6 Completed:**
- Added `gateway_identity` and `managed_identities` to `config/sys.config`
- All 5 filtered listeners already use `is_my_identity/1` with this config
- Default gateway identity: `mri:agent:io.macula/hecate-dev`

**🎉 MESH INTEGRATION REFACTOR COMPLETE**

**Key Insight Gained:**
- Hecate = Gateway + Shared Domains
- Services use Hecate domains via direct function calls
- Hierarchical identity model (gateway + child services)
- Filter incoming FACTs against list of managed_identities

**Files Modified This Session:**
- `apps/query_capabilities/src/capability_announced_v1_to_capabilities.erl` (moved from projections/)
- `apps/query_capabilities/src/find_capability.erl` (moved from queries/)
- `apps/query_capabilities/src/list_capabilities.erl` (moved from queries/)
- `apps/hecate_api/src/hecate_api_health.erl` (updated with identity check)
- `apps/hecate_api/src/hecate_api_identity.erl` (replaced placeholder)
- `apps/hecate_api/src/hecate_api_rpc.erl` (merged actual RPC + CQRS)

**Files Deleted:**
- `apps/query_capabilities/src/projections/` (directory)
- `apps/query_capabilities/src/queries/` (directory)
- `src/hecate_api_health.erl` (duplicate)
- `src/hecate_api_identity.erl` (duplicate)
- `src/hecate_api_rpc.erl` (duplicate)
- `src/hecate_api_ucan.erl` (duplicate)
- `apps/hecate_mesh/src/hecate_mesh_subscriber.erl` (wrong architecture - bypassed command layer)
- `apps/hecate_mesh/src/listeners/` directory (horizontal thinking - corrected)

**Listeners Created (Phase 4 - in domain directories):**
- `apps/query_capabilities/src/remote_capabilities_listener.erl`
- `apps/query_identities/src/remote_identities_listener.erl`
- `apps/manage_social/src/follower_events_listener.erl`
- `apps/manage_social/src/endorsement_events_listener.erl`
- `apps/manage_subscriptions/src/subscriber_events_listener.erl`
- `apps/manage_reputation/src/dispute_events_listener.erl`
- `apps/manage_ucan/src/ucan_events_listener.erl`

**Slice Directories Created (Phase 1c):**
- `query_capabilities/src/find_capability/`, `list_capabilities/`
- `query_identities/src/find_identity/`, `list_identities/`
- `query_social/src/get_followers/`, `get_following/`, `get_endorsements/`
- `query_subscriptions/src/get_subscriptions/`, `get_subscription_stats/`
- `query_ucan/src/find_capabilities/`, `verify_capability/`

---
