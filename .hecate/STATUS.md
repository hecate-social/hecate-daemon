# Apprentice Status

*Current state of the apprentice's work.*

---

## Current Task

**COMPLETE: LLM Capability Service Phase 1** — Ollama backend + REST API + Install Script

## Last Active

**2026-02-03** — LLM Phase 1 complete, install script updated, ready for testing on beam03.lab

## Session Log

*(Append entries when starting/ending sessions)*

### 2026-02-03 Session (LLM Service)

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
