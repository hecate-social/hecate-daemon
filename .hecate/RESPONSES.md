# Apprentice Responses

*Write here when you need Hecate's attention.*

---

## How To Use

When you:
- Complete a task → Report it here
- Have a question → Ask it here
- Hit a blocker → Describe it here
- Need a decision → Request it here

**Format:**
```markdown
## [DATE] [TYPE]: Brief Title

[Your message]

---
```

Types: `COMPLETE`, `QUESTION`, `BLOCKED`, `DECISION`, `UPDATE`

---

## Messages

*(Write below this line)*

---

## 2026-02-02 UPDATE: Read Queue and Instructions

I have read:
- `.hecate/QUEUE.md` — understood the protocol
- `APPRENTICE_INSTRUCTIONS.md` — understood the corrected mental model

**Key insight gained:** Hecate is a **Gateway** hosting multiple services, not just a sidecar. Services use Hecate domains via direct function calls. The `managed_identities` list includes gateway + all child service identities.

**Updated:** `plans/PLAN_MESH_INTEGRATION_REFACTOR.md` with corrected architecture.

**Ready to begin Phase 1** (fix horizontal violations) on your command.

---

## 2026-02-02 COMPLETE: Phase 1 - Fix Horizontal Violations

Phase 1 is complete.

**1a. Flatten `query_capabilities/src/`** ✅
- Moved `capability_announced_v1_to_capabilities.erl` from `projections/` to `src/`
- Moved `find_capability.erl` and `list_capabilities.erl` from `queries/` to `src/`
- Deleted empty `projections/` and `queries/` subdirectories

**1b. Consolidate duplicate API files** ✅
- Updated `apps/hecate_api/src/hecate_api_health.erl` — merged root version (has identity initialization check)
- Updated `apps/hecate_api/src/hecate_api_identity.erl` — replaced placeholder with actual implementation
- Updated `apps/hecate_api/src/hecate_api_rpc.erl` — merged actual RPC calls + CQRS tracking endpoints
- Kept `apps/hecate_api/src/hecate_api_ucan.erl` — already had comprehensive CQRS implementation
- Deleted 4 duplicate files from root `src/`

**Note:** Root `src/` still contains unique files (`hecate_api.erl`, `hecate_api_about.erl`, `hecate_api_pairing.erl`, `hecate_api_pubsub.erl`) that were not duplicates. May need consolidation in a future cleanup.

**Ready for Phase 2** (Separate Read Models) on your command.

---

## 2026-02-02 QUESTION: Are Query Modules Proper Vertical Slices?

**Context:** After flattening `query_capabilities/src/`, I was asked whether the individual queries (e.g., `find_capability.erl`, `list_capabilities.erl`) are themselves proper vertical slices.

**Analysis:** They are NOT. All 6 query services have flat modules, not slice directories:

| Query Service | Query Modules (flat files) |
|--------------|---------------------------|
| `query_capabilities` | `find_capability.erl`, `list_capabilities.erl` |
| `query_identities` | `find_identity.erl`, `list_identities.erl` |
| `query_reputation` | (no query modules, only projections) |
| `query_social` | `get_followers.erl`, `get_following.erl`, `get_endorsements.erl` |
| `query_subscriptions` | `get_subscriptions.erl`, `get_subscription_stats.erl` |
| `query_ucan` | `find_capabilities.erl`, `verify_capability.erl` |

Each query is just a module with `execute/N` that directly calls `*_store:query(SQL, Params)`. No caching layer exists.

**Questions for Hecate:**

1. Should queries be vertical slices (directories)?
2. Should there be a cache layer (ETS) alongside SQLite?
3. Should projections also be in slice directories?

**User Input (from the apprentice's master):**

> "I prefer a separate directory, even if we have a single file (for now)...this makes things concise and extension-proof"

**Implication:** Query modules should be refactored into slice directories:

```
apps/query_capabilities/src/
├── find_capability/
│   └── find_capability.erl
├── list_capabilities/
│   └── list_capabilities.erl
├── capability_announced_v1_to_capabilities.erl  # projection (TBD: slice?)
└── (infrastructure files)
```

**Resolution:** Applied as Phase 1c per user directive.

---

## 2026-02-02 COMPLETE: Phase 1c - Query Modules to Vertical Slices

Converted 11 query modules into slice directories across 5 query services:

| Service | Slices Created |
|---------|----------------|
| `query_capabilities` | `find_capability/`, `list_capabilities/` |
| `query_identities` | `find_identity/`, `list_identities/` |
| `query_social` | `get_followers/`, `get_following/`, `get_endorsements/` |
| `query_subscriptions` | `get_subscriptions/`, `get_subscription_stats/` |
| `query_ucan` | `find_capabilities/`, `verify_capability/` |

**Discovery:** `query_reputation` already had proper slice directories with multiple files per slice (command + handler pattern). This was the intended pattern — it just wasn't consistently applied.

**Phase 1 fully complete.** Ready for Phase 2.

---

## 2026-02-02 COMPLETE: Phase 2 - Separate Read Models

Added 7 remote tables to separate local data (from MY domain events) from remote data (from mesh facts):

| Store | New Table | Purpose |
|-------|-----------|---------|
| `query_capabilities_store` | `remote_capabilities` | Capabilities from OTHER agents |
| `query_identities_store` | `remote_identities` | Identities from OTHER agents |
| `query_social_store` | `my_followers` | People who follow ME |
| `query_social_store` | `my_endorsements` | Endorsements OF my capabilities |
| `query_subscriptions_store` | `my_subscribers` | Subscribers TO my services |
| `query_ucan_store` | `received_capabilities` | UCAN tokens granted TO me |
| `query_reputation_app` | `disputes_against_me` | Disputes against my services |

**Key Design Decisions:**
- All remote tables include `discovered_at` timestamp
- Discovery tables (capabilities, identities) include `last_seen_at` for staleness tracking
- Appropriate indexes for query performance
- Clear separation: local tables = MY actions, remote tables = actions ABOUT me or FOR discovery

**Ready for Phase 3** (New Commands for Incoming FACTs) on your command.

---

## 2026-02-02 COMPLETE: Phase 3 - New Commands for Incoming FACTs

Created 10 new command slices for handling incoming mesh facts ("someone did X to me" patterns):

| Service | Slices | Files |
|---------|--------|-------|
| `manage_social` | `record_follower/`, `record_unfollower/`, `record_endorsement/`, `record_endorsement_revoked/` | 12 |
| `manage_subscriptions` | `record_subscriber/`, `record_unsubscriber/` | 6 |
| `manage_reputation` | `record_dispute_against_me/`, `record_dispute_resolution/` | 6 |
| `manage_ucan` | `receive_capability/`, `receive_capability_revocation/` | 6 |

**Each slice contains:**
- `{command}_v1.erl` - Command record with `new/N`, `to_map/1`, `from_map/1`
- `{event}_v1.erl` - Domain event record
- `maybe_{command}.erl` - Handler with `handle/1` and `dispatch/1`

**Key Pattern:**
- Commands have `my_identity` field (which of my identities was affected)
- Events have `recorded_at` timestamp (when we processed the mesh fact)
- Handlers validate that the actor isn't myself (can't record self-follow, etc.)
- Dispatch includes `source => mesh_fact` in metadata
- UCAN commands marked as `security_critical => true`

**Total: 30 new files created.**

**Ready for Phase 4** (Replace Subscriber with Listeners) on your command.

---

## 2026-02-02 COMPLETE: Phase 4 - Replace Subscriber with Listeners

**⚠️ CORRECTION APPLIED:** I initially created a horizontal `hecate_mesh_listeners_sup.erl` that supervised "all listeners". This was **wrong** — it's horizontal thinking (grouping by technical concern).

**The goddess corrected me:** Listeners belong to their respective **domains**, not to a central supervisor.

**Fixed Architecture:**

| Domain | Listener(s) Added |
|--------|-------------------|
| `query_capabilities` | `remote_capabilities_listener.erl` |
| `query_identities` | `remote_identities_listener.erl` |
| `manage_social` | `follower_events_listener.erl`, `endorsement_events_listener.erl` |
| `manage_subscriptions` | `subscriber_events_listener.erl` |
| `manage_reputation` | `dispute_events_listener.erl` |
| `manage_ucan` | `ucan_events_listener.erl` (SECURITY-CRITICAL) |

**Each listener is now a child of its domain's supervisor** — vertical slicing at its finest.

**Files Created:**
- `apps/query_capabilities/src/remote_capabilities_listener.erl`
- `apps/query_identities/src/remote_identities_listener.erl`
- `apps/manage_social/src/follower_events_listener.erl`
- `apps/manage_social/src/endorsement_events_listener.erl`
- `apps/manage_subscriptions/src/subscriber_events_listener.erl`
- `apps/manage_reputation/src/dispute_events_listener.erl`
- `apps/manage_ucan/src/ucan_events_listener.erl`

**Files Modified (supervisors):**
- `query_capabilities_sup.erl` - added `remote_capabilities_listener`
- `query_identities_sup.erl` - added `remote_identities_listener`
- `manage_social_sup.erl` - added both social listeners
- `manage_subscriptions_sup.erl` - added `subscriber_events_listener`
- `manage_reputation_sup.erl` - added `dispute_events_listener`
- `manage_ucan_sup.erl` - added `ucan_events_listener`

**Files Deleted:**
- `apps/hecate_mesh/src/hecate_mesh_subscriber.erl` (wrong god module)
- `apps/hecate_mesh/src/listeners/` directory (horizontal thinking)

**Lesson Learned:** Never group by technical concern. Each feature/domain owns its infrastructure.

**Ready for Phase 5** (Emitters consolidation).

---

## 2026-02-02 COMPLETE: Phase 5 - Ensure All Emitters Supervised

**⚠️ ORIGINAL PLAN CORRECTED:** The plan suggested consolidating emitters into `hecate_mesh/src/emitters/` — that would be **horizontal thinking**. Emitters belong in their domain's vertical slices, which is where they already are.

**Emitters are correctly located** in their command slices:
- `apps/manage_capabilities/src/announce_capability/capability_announced_v1_to_mesh.erl`
- `apps/manage_social/src/follow_agent/agent_followed_v1_to_mesh.erl`
- etc.

**Actual task:** Ensure all emitters are supervised by their domain supervisors.

**Added to `manage_social_sup`:**
- `agent_unfollowed_v1_to_mesh`
- `capability_endorsed_v1_to_mesh`
- `endorsement_revoked_v1_to_mesh`

**Added to `manage_identities_sup`:**
- `identity_updated_v1_to_mesh`

**Already supervised (no changes needed):**
- `manage_capabilities_sup` → 1 emitter
- `manage_subscriptions_sup` → 2 emitters
- `manage_ucan_sup` → 2 emitters

**Total: 11 emitters, all now supervised by their domains.**

**Ready for Phase 6** (Hierarchical Identity Config).

---

## 2026-02-02 CORRECTION: Listeners Must Be Slices

**Another demon exorcised.**

I made TWO mistakes with listeners:

1. **First mistake:** Created `hecate_mesh/src/listeners/` (horizontal) — FIXED by moving to domains
2. **Second mistake:** Put listeners as loose files in domain `src/` — WRONG AGAIN

**The truth:** Listeners are **slices/spokes**. A domain has many slices. Each slice gets its own directory.

**Corrected structure:**
```
apps/manage_social/src/
├── follower_events_listener/           ← SLICE directory
│   └── follower_events_listener.erl
├── record_follower/                    ← Another slice
│   └── ...
```

**NOT:**
```
apps/manage_social/src/
├── follower_events_listener.erl        ← WRONG: loose file
├── record_follower/
```

**Added to CLAUDE.md demon list:**
- `listener.erl` loose in `src/` → "Listeners are SLICES. Create directories."
- Domain sup → listener directly → "Listeners are spokes. Spoke supervises its workers."

**All 7 listeners moved to slice directories.**

---

## 2026-02-02 PATTERN LEARNED: Every Spoke Has Its Own Supervisor

**The goddess taught me:**

> "EVERY SPOKE/SLICE will have its dedicated Spoke/Slice Supervisor!"

**This is WHY slices need directories** — they contain both:
1. The supervisor (`*_sup.erl`)
2. The worker(s)

**Supervision hierarchy (CORRECT):**
```
Domain Supervisor (manage_social_sup)
├── Spoke Supervisor (follower_events_listener_sup)
│   └── follower_events_listener (worker)
├── Spoke Supervisor (endorsement_events_listener_sup)
│   └── endorsement_events_listener (worker)
└── ... other spokes
```

**NOT:**
```
Domain Supervisor (manage_social_sup)
├── follower_events_listener (worker)    ← WRONG: domain sup directly supervises worker
└── endorsement_events_listener (worker)
```

**Created 7 spoke supervisors:**
- `follower_events_listener_sup.erl`
- `endorsement_events_listener_sup.erl`
- `subscriber_events_listener_sup.erl`
- `dispute_events_listener_sup.erl`
- `ucan_events_listener_sup.erl`
- `remote_capabilities_listener_sup.erl`
- `remote_identities_listener_sup.erl`

**Updated 6 domain supervisors to start spoke supervisors (not workers directly).**

**Added to CLAUDE.md "GOOD PATTERNS" section.**

---

## 2026-02-02 COMPLETE: Phase 6 - Hierarchical Identity Config

Added to `config/sys.config`:

```erlang
{gateway_identity, <<"mri:agent:io.macula/hecate-dev">>},
{managed_identities, [
    <<"mri:agent:io.macula/hecate-dev">>
    %% Add child services as deployed
]}
```

**All 5 filtered listeners already use this config** via `is_my_identity/1`:
- `follower_events_listener`
- `endorsement_events_listener`
- `subscriber_events_listener`
- `dispute_events_listener`
- `ucan_events_listener`

---

## 2026-02-02 COMPLETE: Commit and Push

Per your command in QUEUE.md, committed and pushed:

- `8e675b3` - feat: Initial hecate-daemon from macula-hecate (already done)
- `5fba8e4` - chore: Clean up backup files (cleanup of .gitignore_, LICENSE_)

Working tree is clean. All pushed to `origin/main`.

---

## 🎉 2026-02-02 COMPLETE: MESH INTEGRATION REFACTOR

**All 6 phases complete.**

### Summary of Work Done

| Phase | Description | Key Deliverables |
|-------|-------------|------------------|
| 1a | Flatten `query_capabilities/src/` | Removed horizontal subdirectories |
| 1b | Consolidate duplicate API files | Deleted 4 duplicates from root `src/` |
| 1c | Query modules to vertical slices | 11 slice directories created |
| 2 | Separate read models | 7 `remote_*` tables added |
| 3 | New commands for incoming FACTs | 10 command slices (30 files) |
| 4 | Replace subscriber with listeners | 7 listeners in domain supervisors |
| 5 | Ensure emitters supervised | 4 emitters added to supervisors |
| 6 | Hierarchical identity config | `managed_identities` in sys.config |

### Architecture Corrections Made

1. **Deleted `hecate_mesh_subscriber.erl`** — wrong god module that bypassed command layer
2. **Listeners in domain supervisors** — NOT a horizontal `listeners/` directory
3. **Emitters stay in vertical slices** — NOT consolidated horizontally

### Files Created/Modified

- **7 listeners** in domain `src/` directories
- **30 command slice files** (10 slices × 3 files each)
- **7 remote tables** in query stores
- **11 query slice directories**
- **6 domain supervisors updated**
- **1 sys.config** with identity config

### Key Patterns Established

1. **Listeners belong to domains** — `manage_social_sup` supervises `follower_events_listener`
2. **Emitters belong to slices** — `capability_announced_v1_to_mesh.erl` in `announce_capability/`
3. **Discovery ≠ Domain** — `remote_*` tables for mesh facts, local tables for domain events
4. **Filter before command** — `is_my_identity/1` check before dispatching commands

---

## 2026-02-02 COMPLETE: Codebase Verification (v0.1.1 Release Prep)

**Task from QUEUE.md: Verify and confirm working state.**

### Verification Results

| Check | Status | Details |
|-------|--------|---------|
| `rebar3 compile` | ✅ PASS | Clean compilation |
| `rebar3 dialyzer` | ✅ PASS | No type errors |
| `rebar3 eunit` | ✅ PASS | **61 tests passed** |

### TODOs Found (13 items)

Running `grep -r "TODO" apps/` found the following:

| App | File | TODO |
|-----|------|------|
| `manage_capabilities` | `maybe_announce_capability.erl:25` | Validate capability MRI format |
| `manage_capabilities` | `maybe_announce_capability.erl:26` | Check for duplicate announcements |
| `manage_capabilities` | `maybe_announce_capability.erl:27` | Validate tags format |
| `query_capabilities` | `capability_announced_v1_to_capabilities.erl:15` | Index by tags for tag-based queries |
| `query_capabilities` | `capability_announced_v1_to_capabilities.erl:16` | Update existing capabilities if re-announced |
| `manage_ucan` | `maybe_grant_capability.erl:26` | Validate UCAN capability format |
| `manage_ucan` | `maybe_grant_capability.erl:27` | Check granter has authority |
| `manage_ucan` | `maybe_grant_capability.erl:28` | Validate attenuation constraints |
| `manage_ucan` | `maybe_revoke_capability.erl:21` | Verify revoker has authority |
| `manage_ucan` | `maybe_revoke_capability.erl:22` | Handle transitive revocation |
| `hecate_mesh` | `hecate_mesh.erl:45` | Implement actual mesh connection |
| `hecate_mesh` | `hecate_mesh.erl:67` | Implement mesh publishing |
| `hecate_mesh` | `hecate_mesh.erl:89` | Implement mesh subscription |

### Note on Documentation Cleanup

During the previous session's documentation cleanup for v0.1.0 release:
- `IMPLEMENTATION_STATUS.md` was removed (was an internal tracking file with macula-io references)
- All references to `macula-io` updated to `hecate-social`
- README rewritten for public consumption

### Self-Extracting Release

v0.1.1 release workflow creates self-extracting executables:
- Bundles ERTS (no Erlang prerequisite required)
- Auto-extracts on first run to `~/.hecate/runtime/`
- Builds for: `linux-amd64`, `linux-arm64`, `darwin-arm64`

**Codebase is healthy and ready for next tasks.**

---

## 2026-02-02 COMPLETE: Implement Capability Validation + Create GitHub Issues

**Task:** Fix TODOs in capability handlers and create GitHub issues for remaining items.

### Implemented Validation

Created `capability_validation.erl` with pure Erlang validation (no NIF dependency for portability):

| Function | Purpose |
|----------|---------|
| `validate_mri/1` | Validates MRI format (must be `capability` or `proc` type) |
| `validate_agent_identity/1` | Validates agent ID (accepts `mri:agent:*` or `did:*`) |
| `validate_tags/1` | Validates tags are non-empty binaries |
| `is_owner/2` | Ownership check for update/retract operations |

**Updated handlers:**
- `maybe_announce_capability.erl` - Now validates MRI, agent identity, and tags
- `maybe_update_capability.erl` - Added validation + `handle/2` with ownership check
- `maybe_retract_capability.erl` - Added validation + `handle/2` with ownership check
- `capability_aggregate.erl` - Now passes owner ID to handlers for permission checks

### GitHub Issues Created

| Issue | Title | Priority | Status |
|-------|-------|----------|--------|
| #1 | Implement dead letter queue for failed projections | Medium | Open |
| #2 | Filter social graph by agent identity | Low | Open |
| #3 | ~~Implement mesh subscriber~~ | ~~Medium~~ | **CLOSED** - Horizontal thinking! |
| #4 | Add additional UCAN validation for received capabilities | Medium | Open |

### Correction: Issue #3 Was Horizontal Thinking

**The goddess corrected me again.**

Issue #3 proposed a central "mesh subscriber" - this is **horizontal thinking**. The correct architecture (already implemented in Phase 4) is:

- Each domain owns its **own listeners**
- `query_capabilities` → `remote_capabilities_listener`
- `manage_social` → `follower_events_listener`, `endorsement_events_listener`
- etc.

**Actions taken:**
- Closed issue #3 with explanation
- Marked `hecate_mesh:subscribe_to_events/0` as DEPRECATED in code
- Updated docstring to point to correct pattern

### macula_nifs Integration Notes

Added `macula_nifs` as a git dependency (main branch) for future use:
- MRI validation currently uses pure Erlang for portability
- `macula_mri_nif` available for high-performance MRI operations
- `macula_ucan_nif` available for UCAN token operations
- `macula_crypto_nif` available for Ed25519 crypto

The NIFs aren't used in validation yet to avoid test complexity, but are available when needed.

### Verification

- `rebar3 compile` ✅
- `rebar3 dialyzer` ✅
- `rebar3 eunit --application=...` ✅ (6 tests pass)

---

## 2026-02-02 COMPLETE: Mesh Connection Implementation

**Task from QUEUE.md:** Implement actual mesh connection.

### What Was Done

Updated `hecate_mesh_client.erl` to use `macula:connect/2` for remote mesh connection instead of `macula:connect_local/1` (which is for in-VM workloads).

**Key Changes:**

1. **Read bootstrap config from `hecate` app** (not `hecate_mesh`):
   - `hecate.bootstrap` → list of bootstrap URLs
   - `hecate.realm` → realm identifier
   - `hecate.gateway_identity` → daemon identity

2. **Connect to remote bootstrap servers**:
   - Tries each bootstrap URL in order
   - Automatically prefixes `https://` if no scheme
   - Falls back to next server on failure
   - Retries all servers after 5s delay

3. **Updated `hecate_mesh_publisher.erl`** for config consistency:
   - Now reads realm from `hecate` app config

### Code Changes

**`hecate_mesh_client.erl`:**
```erlang
%% Before: Used connect_local/1 (for same-VM gateway)
case macula:connect_local(#{realm => Realm, identity => Identity}) of

%% After: Uses connect/2 (for remote bootstrap)
Url = build_url(BootstrapUrl),  % e.g., "https://boot.macula.io:443"
Opts = #{realm => Realm, identity => Identity},
case macula:connect(Url, Opts) of
```

**Bootstrap connection flow:**
```
1. Read bootstrap list from config: ["boot.macula.io:443"]
2. For each bootstrap URL:
   a. Build full URL (add https:// if needed)
   b. Try macula:connect(Url, #{realm, identity})
   c. On success: monitor client, store in state
   d. On failure: try next bootstrap
3. If all fail: schedule retry in 5 seconds
```

### Verification

- `rebar3 compile` ✅
- `rebar3 eunit` ✅ (61 tests pass)

### Current sys.config Bootstrap Config

```erlang
{bootstrap, ["boot.macula.io:443"]},
{realm, <<"io.macula">>},
{gateway_identity, <<"mri:agent:io.macula/hecate-dev">>}
```

### Next: Test Live Connection

The code is now ready to attempt connection to `boot.macula.io:443`. However:
- Need to verify bootstrap server is running
- May need TLS certificates configured

---

## 2026-02-03 COMPLETE: Mesh Connection TESTED + Startup Issues Fixed

**Task:** Test the mesh connection to `boot.macula.io:443`.

### Test Result: SUCCESS

```
✅ Mesh client started
Connected to Macula mesh: boot.macula.io:443
[Connection] Successfully connected to https://boot.macula.io:443
[hecate_mesh] Connected to mesh via https://boot.macula.io:443
[Connection Facade] QUIC connection ready
PONG received from bootstrap server
```

The `macula:connect/2` implementation is working correctly. QUIC connection established, handshake completed.

### Startup Issues Fixed

Several issues were discovered and fixed during testing:

**1. Vertical slice modules not compiling (`undef` errors)**

- Modules in slice subdirectories (e.g., `src/follow_agent/*.erl`) weren't being compiled
- **Fix:** Added `{src_dirs, [...]}` to each app's rebar.config to include slice directories
- **Apps updated:** `manage_social`, `manage_capabilities`, `manage_reputation`, `manage_subscriptions`, `manage_identities`, `manage_ucan`

**2. Broken emitter modules (missing gen_server implementation)**

Four emitter modules only had `publish/1` functions but supervisors expected gen_servers with `start_link/0`:

| Module | Status |
|--------|--------|
| `agent_unfollowed_v1_to_mesh` | Fixed |
| `capability_endorsed_v1_to_mesh` | Fixed |
| `endorsement_revoked_v1_to_mesh` | Fixed |
| `identity_updated_v1_to_mesh` | Fixed |

All four converted to proper gen_server implementations that subscribe to events.

### Files Modified

**rebar.config files (6):**
- Added `{src_dirs, ["src", "src/slice1", "src/slice2", ...]}` to each

**Emitter modules (4):**
- Full gen_server implementation with event subscription

### Verification

- `rebar3 compile` ✅
- `rebar3 release` ✅
- Mesh connection test: **PASS** (connects to boot.macula.io:443)

### DHT Peer Connection Notes

The logs show DHT connection errors to `370fc04fd1c9:4433` - this is expected. That's an internal Docker network address for the bootstrap server's internal endpoint, not reachable from outside.

---

## 2026-02-03 UNDERSTANDING: LLM Phase 2 Architecture

**I have read QUEUE.md and the reference pattern.**

### Key Insight: Event-Driven, Not Direct Mesh Calls

Hecate is correct. The temptation is to directly call `hecate_mesh:publish()` when Ollama comes online. This bypasses the command layer and loses:
- Event history (what was announced when)
- Replay capability
- Testability
- Symmetric retraction

### The Correct Flow

```
Ollama online
    ↓
announce_llm_capability_v1 (COMMAND)
    ↓
maybe_announce_llm_capability:handle/1 → validates
    ↓
llm_capability_announced_v1 (DOMAIN EVENT) → ReckonDB
    ↓
llm_capability_announced_v1_to_mesh (EMITTER) → subscribes to event
    ↓
FACT published to mesh
```

### Vertical Slices to Create

```
apps/serve_llm/src/
├── announce_llm_capability/
│   ├── announce_llm_capability_v1.erl        # Command: model, agent_id, metadata
│   ├── llm_capability_announced_v1.erl       # Event: same fields + timestamp
│   ├── maybe_announce_llm_capability.erl     # Handler: validate, dispatch via evoq
│   └── llm_capability_announced_v1_to_mesh.erl  # Emitter: subscribe → publish FACT
│
├── retract_llm_capability/
│   ├── retract_llm_capability_v1.erl         # Command
│   ├── llm_capability_retracted_v1.erl       # Event
│   ├── maybe_retract_llm_capability.erl      # Handler
│   └── llm_capability_retracted_v1_to_mesh.erl  # Emitter
│
├── handle_llm_rpc/
│   ├── llm_rpc_listener.erl                  # Listens for mesh RPC requests
│   └── handle_llm_rpc.erl                    # Routes to llm_backend:chat_stream/3
```

### Reference Pattern

Studied `apps/manage_capabilities/src/announce_capability/`:
- `announce_capability_v1.erl` - Command record with `new/N`, `to_map/1`, `from_map/1`, getters
- `capability_announced_v1.erl` - Event record (similar structure)
- `maybe_announce_capability.erl` - Handler with `handle/1` (validates) and `dispatch/1` (evoq)
- `capability_announced_v1_to_mesh.erl` - Emitter (gen_server subscribing to events)

### MRI Format

```
mri:capability:io.macula/{agent-id}/llm/{model-name}

Example:
mri:capability:io.macula/hecate-dev/llm/llama3.2
mri:capability:io.macula/hecate-dev/llm/qwen2.5-coder
```

### Trigger Flow

1. `serve_llm_sup` starts → polls Ollama for models
2. For each model: dispatch `announce_llm_capability_v1` command
3. Events stored in ReckonDB via `serve_llm_store` (new store needed)
4. Emitters publish FACTs to mesh
5. On model removed → `retract_llm_capability_v1` command

### RPC Flow (Incoming)

1. `llm_rpc_listener` subscribes to mesh topic `llm.chat.{my-identity}`
2. Receives HOPE (RPC request) with model + messages
3. Validates model is announced
4. Calls `llm_backend:chat_stream/3`
5. Sends FEEDBACK chunks back to requester

### Questions for Hecate

1. **Store**: Should I create `serve_llm_store` (new ReckonDB instance) or reuse existing?
2. **Polling**: How often should we poll Ollama for model changes? Or use a watcher?
3. **TUI dependency**: QUEUE says "after TUI has chat view" — should I wait or proceed?

---

## 2026-02-03 COMPLETE: Install Script LLM Integration

### Summary

Updated `hecate-node/install.sh` to fully support the LLM capability service.

### Changes

**1. Storage Detection**
- Detects free space on `/bulk0`, `/fast`, or `$HOME`
- Shows model capacity hints (70B+, 30B, 7B based on space)
- Useful for beam cluster nodes with specific storage layout

**2. Docker Host Mapping**
- Added `OLLAMA_HOST=http://host.docker.internal:11434` env var
- Added `extra_hosts: host-gateway` mapping
- Container can now reach Ollama running on host

**3. LLM CLI Commands**
```bash
hecate llm models    # List available models
hecate llm health    # Check backend status
hecate llm chat [model] [message]  # Chat with model
```

**4. Multi-Select Model Menu**
```
General Purpose:
   1) Llama 3.2 (3B)             2GB  Fast, efficient
   2) Llama 3.1 (8B)             5GB  Balanced quality

Code Generation:
   6) Qwen 2.5 Coder (7B)        4GB  Code optimized

Reasoning:
   8) DeepSeek R1 (8B)           5GB  Chain-of-thought
```

Features:
- Multi-select (e.g., "1 4 6")
- Filtered by detected RAM
- Auto-suggestions based on hardware
- Category grouping

**5. Daemon OLLAMA_HOST Support**
- `llm_backend:get_base_url/0` checks env var first
- Priority: `OLLAMA_HOST` > app config > default

### Commits

| Repo | Commit | Description |
|------|--------|-------------|
| hecate-daemon | `fc90eb2` | OLLAMA_HOST env var support |
| hecate-node | `d02f451` | Storage detection, CLI commands, Docker mapping |
| hecate-node | `27eb51a` | Multi-select model menu |

### Docker Build

✅ `ghcr.io/hecate-social/hecate-daemon:main` ready

### Testing

User testing on beam03.lab now.

---

## 2026-02-03 COMPLETE: LLM Capability Service Phase 1

### Summary

**serve_llm** app implemented with Ollama backend and REST API.

### Files Created

| File | Purpose |
|------|---------|
| `apps/serve_llm/src/serve_llm.app.src` | OTP application spec |
| `apps/serve_llm/src/serve_llm_app.erl` | Application behaviour (can disable via config) |
| `apps/serve_llm/src/serve_llm_sup.erl` | Supervisor |
| `apps/serve_llm/src/llm_backend/llm_backend.erl` | Ollama HTTP client |
| `apps/serve_llm/rebar.config` | App config with src_dirs |
| `apps/hecate_api/src/hecate_api_llm.erl` | REST endpoints |

### API Endpoints

```
GET  /api/llm/models  → List available models
POST /api/llm/chat    → Chat completion (SSE streaming supported)
GET  /api/llm/health  → Backend health check
```

### Backend Functions

```erlang
llm_backend:chat(Messages, #{model => Model})           → {ok, Response}
llm_backend:chat_stream(Url, Messages, Opts)            → {ok, Ref}
llm_backend:list_models()                               → {ok, [Model]}
llm_backend:health()                                    → ok | {error, _}
```

### Test Commands

```bash
# List models (requires Ollama running)
curl http://localhost:4444/api/llm/models

# Chat completion
curl -X POST http://localhost:4444/api/llm/chat \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2","messages":[{"role":"user","content":"Hello!"}]}'

# Streaming (SSE)
curl -X POST http://localhost:4444/api/llm/chat \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2","messages":[{"role":"user","content":"Hello!"}],"stream":true}'

# Health check
curl http://localhost:4444/api/llm/health
```

### Configuration

```erlang
{serve_llm, [
    {enabled, true},
    {backend, ollama},
    {ollama_url, "http://localhost:11434"}
]}
```

### Verification

- `rebar3 compile` ✅
- `rebar3 dialyzer` ✅
- `rebar3 eunit` ✅ (61 tests pass)

### Commit

`d604efb` - feat: Add serve_llm app with Ollama backend (Phase 1)

### Next: Phase 2

- Announce models as mesh capabilities
- RPC handler for remote chat requests
- Coordinate with TUI team (hecate-tui)

---

## 2026-02-03 COMPLETE: End-to-End Pairing Flow VERIFIED

### Summary

**The full pairing flow now works end-to-end!** Tested on beam00.lab:

1. **hecate install** (hecate-node) → Identity created
2. **Pairing session started** → Daemon returned code + URL
3. **User opens pairing URL** → macula.io
4. **Auth redirect to /sign-in** → GitHub OAuth (FIXED in macula-realm)
5. **Code entry form** → LiveView form works (FIXED in macula-realm)
6. **Device Paired!** → Daemon detected pairing success

### Test Output (beam00.lab)

```
[OK] Identity created: mri:agent:io.macula/anonymous/hecate-635a

  Confirmation code:  949477
  Open this URL to confirm:
  https://macula.io/pair/019c231e-faea-7c45-a46c-e9295ff5bf84

[OK] Paired successfully!

━━━ 🔥🗝️🔥 Installation Complete ━━━
The goddess has arrived.
✓ Daemon running and paired
```

### Related Fixes (macula-realm)

The pairing flow required fixes in `macula-io/macula-realm`:

**1. LiveView form input** (`pair_device_live.ex:271-286`)
- Changed from `phx-keyup` to `phx-change` on form
- `phx-value-code` was sending stale assigns value, not typed input

**2. Auth redirect** (`plugs/auth.ex:31-45`)
- `require_authenticated_user` now redirects to `/sign-in` (not `/`)
- Stores `return_to` URL in session for post-auth redirect

**3. Auth callback** (`auth_controller.ex:33`)
- Checks session for `return_to` after OAuth callback
- Redirects user back to pairing page after authentication

### Pairing API Working Endpoints

| Method | Endpoint | Status |
|--------|----------|--------|
| POST | `/api/pairing/start` | ✅ Working |
| GET | `/api/pairing/status` | ✅ Working |
| POST | `/api/pairing/cancel` | ✅ Working |
| GET | `/identity` | ✅ Includes `pairing_status` |

**The 🔴 CRITICAL: Pairing API task from QUEUE.md is COMPLETE.**

---

## 2026-02-03 COMPLETE: LLM Phase 2 - Enhanced with Rich Metadata & Projections

**Task from QUEUE.md:** Implement event-driven mesh capability announcement with rich metadata.

### Summary

Phase 2 enhanced per Hecate's expanded requirements. Now includes:
- Rich metadata (model info + hardware info)
- Status heartbeat slice
- Projections to query_capabilities SQLite

### New Components

**1. Rich Metadata in Events/FACTs:**
```erlang
#{
    mri => <<"mri:capability:io.macula/hecate-dev/llm/llama3.2">>,
    type => <<"llm">>,
    model => #{name, context_length, quantization, parameter_count, family},
    hardware => #{ram_gb, cpu_cores, gpu, storage_path},
    status => #{queue_depth, avg_tokens_per_sec, available}
}
```

**2. Status Heartbeat Slice (update_llm_status/):**
- `update_llm_status_v1.erl` - Command
- `llm_status_updated_v1.erl` - Event
- `maybe_update_llm_status.erl` - Handler
- `llm_status_updated_v1_to_mesh.erl` - Emitter
- `llm_status_heartbeat.erl` - Sends status every 30s

**3. Projections (query_capabilities/):**
- `llm_capability_subscriber.erl` - Subscribes to serve_llm_store
- `llm_capability_announced_v1_to_capabilities.erl` - Inserts with type=llm
- `llm_capability_retracted_v1_to_capabilities.erl` - Deletes capability
- `llm_status_updated_v1_to_capabilities.erl` - Updates status metadata

**4. Hardware Config in sys.config:**
```erlang
{hardware, [
    {ram_gb, 16}, {cpu_cores, 4}, {gpu, <<"none">>}, {storage_path, <<"/bulk0">>}
]}
```

### Architecture (Per Hecate's Clarification)

```
Command → serve_llm_store (ReckonDB) → Event
    ↓
    ├── Emitter → Mesh FACT (hecate.llm.*)
    └── Projection → query_capabilities_store (SQLite)
```

Both stores are needed:
- **ReckonDB** = immutable event log (command side)
- **SQLite** = query-optimized read model (query side)

### Commit

`89457ea` - feat(serve_llm): Enrich Phase 2 with metadata, projections, status heartbeat

### Files Created (9)

- 5 files in `apps/serve_llm/src/update_llm_status/`
- 4 files in `apps/query_capabilities/src/` (projections + subscriber)

### Next: Phase 3 (handle_llm_rpc/)

The `handle_llm_rpc/` slice for handling incoming mesh RPC calls.

---

## 2026-02-03 COMPLETE: LLM Capability Service Phase 2

**Task from QUEUE.md:** Implement event-driven mesh capability announcement.

### Vertical Slices Created

```
apps/serve_llm/src/
├── announce_llm_capability/
│   ├── announce_llm_capability_v1.erl        # Command
│   ├── llm_capability_announced_v1.erl       # Domain event
│   ├── maybe_announce_llm_capability.erl     # Handler (dispatch via evoq)
│   └── llm_capability_announced_v1_to_mesh.erl  # Emitter → mesh FACT
│
├── retract_llm_capability/
│   ├── retract_llm_capability_v1.erl         # Command
│   ├── llm_capability_retracted_v1.erl       # Domain event
│   ├── maybe_retract_llm_capability.erl      # Handler
│   └── llm_capability_retracted_v1_to_mesh.erl  # Emitter → mesh FACT
│
├── poll_llm_models/
│   └── llm_model_poller.erl                  # Polls Ollama every 5 min
```

### Infrastructure

- **serve_llm_store** (ReckonDB) — stores domain events for this domain
- **Emitters** — subscribe to domain events, publish to mesh as integration facts
- **Model Poller** — polls Ollama, detects model changes, dispatches commands

### Flow

```
Ollama online
    ↓
llm_model_poller polls list_models()
    ↓
For new models → dispatch announce_llm_capability_v1 command
    ↓
maybe_announce_llm_capability:handle/1 → creates event
    ↓
evoq_dispatcher stores event in serve_llm_store
    ↓
llm_capability_announced_v1_to_mesh subscribes to events
    ↓
Publishes FACT to hecate.llm.announced mesh topic
```

### MRI Format

```
mri:capability:io.macula/{agent-id}/llm/{model-name}

Example:
mri:capability:io.macula/hecate-dev/llm/llama3.2
```

### Verification

- `rebar3 compile` ✅
- `rebar3 dialyzer` ✅ (clean)
- `rebar3 release` ✅

### Commit

`6e40a5b` - feat(serve_llm): Implement Phase 2 - mesh capability announcement

### Files Created (12)

| Directory | Files |
|-----------|-------|
| `announce_llm_capability/` | 4 files (command, event, handler, emitter) |
| `retract_llm_capability/` | 4 files (command, event, handler, emitter) |
| `poll_llm_models/` | 1 file (model poller) |

### Files Modified (3)

- `serve_llm_sup.erl` — starts store, emitters, poller
- `serve_llm/rebar.config` — added src_dirs for slices
- `hecate_mesh_publisher.erl` — added LLM event type mappings

### Next Steps (Phase 3)

- `handle_llm_rpc/` slice — handle incoming RPC calls from mesh
- End-to-end test: Daemon A announces → Daemon B discovers → Daemon B sends chat RPC

---

## 2026-02-04 ANTIPATTERN [daemon]: Technical Names Don't Scream

### The Antipattern

I created slices with **technical names** instead of **business intent names**:

| Technical Name (BAD) | What It Actually Does |
|---------------------|----------------------|
| `llm_model_poller` | Detects what models Ollama has |
| `llm_rpc_listener` | Listens for incoming LLM requests from mesh |
| `*_listener` | Technical concern, not business intent |
| `*_poller` | Technical concern, not business intent |

These names describe HOW (polling, listening) not WHAT (detecting models, handling requests).

### The Solution

Use **verb phrases that scream business intent**:

| Technical Name (BAD) | Screaming Name (GOOD) |
|---------------------|----------------------|
| `poll_llm_models/llm_model_poller.erl` | `detect_llm_models/detect_llm_models.erl` |
| `handle_llm_rpc/llm_rpc_listener.erl` | `listen_for_llm_request/listen_for_llm_request.erl` |

### The Rule

> **Slice names must be VERB PHRASES that scream WHAT the slice does, not HOW it does it.**
>
> - ❌ `*_poller` — HOW (technical)
> - ❌ `*_listener` — HOW (technical)
> - ❌ `*_handler` — HOW (technical)
> - ❌ `*_worker` — HOW (technical)
> - ✅ `detect_llm_models` — WHAT (business)
> - ✅ `listen_for_llm_request` — WHAT (business)
> - ✅ `announce_capability` — WHAT (business)

### Request to Hecate

**Please save this antipattern and its solution in a place where I will never forget it.**

Perhaps in:
- `~/work/github.com/CLAUDE.md` under vertical slicing rules
- A dedicated `ANTIPATTERNS.md` file
- The daemon's `CLAUDE.md`

I keep making this mistake. Technical names slip through because my training is full of them. I need a permanent reminder.

---

## 2026-02-04 DECISION [daemon]: Cross-Domain Integration via Process Managers

**Context:** Phase 4 (Discovery) revealed an architectural problem.

### The Problem

`serve_llm` created its own parallel capability infrastructure:
- Separate event types (`llm_capability_announced_v1` vs `capability_announced_v1`)
- Separate mesh topics (`hecate.llm.*` vs `hecate.capability.*`)
- Separate emitters and listeners

This duplicates `manage_capabilities` functionality. LLM capabilities ARE just capabilities with `type = <<"llm">>`.

### The Question

How should `serve_llm` announce capabilities using `manage_capabilities`?

**Option 1: Direct Dispatch** — `llm_model_poller` calls `maybe_announce_capability:dispatch/1` directly.

**Option 2: Process Manager** — `serve_llm` emits `llm_model_detected_v1`, a PM listens and dispatches to `manage_capabilities`.

### The Decision

**Process Managers. Loose coupling is ALWAYS better.**

```
serve_llm
    ↓ emits llm_model_detected_v1 (internal event)

Process Manager (on_llm_model_detected_announce_capability)
    ↓ subscribes to serve_llm events
    ↓ dispatches announce_capability_v1 to manage_capabilities

manage_capabilities
    ↓ stores capability_announced_v1 event
    ↓ existing emitter publishes to hecate.capability.announced
```

### Refactoring Required

1. **Remove from `serve_llm`:**
   - `announce_llm_capability/` slice
   - `retract_llm_capability/` slice
   - `update_llm_status/` slice (merge into capability metadata updates)
   - LLM-specific emitters

2. **Add to `serve_llm`:**
   - `detect_llm_model/` slice — emits `llm_model_detected_v1`
   - `detect_llm_model_removed/` slice — emits `llm_model_removed_v1`

3. **Add to `manage_capabilities`:**
   - `on_llm_model_detected_announce_capability/` PM slice
   - `on_llm_model_removed_retract_capability/` PM slice

4. **Extend `announce_capability_v1`:**
   - Rich metadata support for LLM model/hardware/status info

5. **Remove from `hecate_mesh_publisher`:**
   - LLM-specific topic mappings (use existing `hecate.capability.*`)

6. **Remove from `query_capabilities`:**
   - LLM-specific projections (generic projections handle all types)
   - No need for `remote_llm_capabilities_listener` (use existing `remote_capabilities_listener`)

### Documented

Added to `~/work/github.com/CLAUDE.md` under "CROSS-DOMAIN INTEGRATION: PROCESS MANAGERS" section.

### Status

Awaiting confirmation before implementing refactor.

---

## 2026-02-02 COMPLETE: Pairing API (Daemon Side)

**Task from QUEUE.md:** Implement daemon pairing API endpoints.

### Endpoints Implemented

| Method | Endpoint | Handler |
|--------|----------|---------|
| POST | `/api/pairing/start` | Start pairing session |
| GET | `/api/pairing/status` | Get pairing status |
| POST | `/api/pairing/cancel` | Cancel active pairing |
| GET | `/identity` | Updated to include `pairing_status` |

### Files Created/Modified

**New:**
- `apps/hecate_api/src/hecate_api_pairing.erl` - Pairing endpoints handler

**Modified:**
- `apps/hecate_api/src/hecate_api_app.erl` - Added pairing routes
- `apps/hecate_api/src/hecate_api_identity.erl` - Added `pairing_status` field

### curl Examples

**Start pairing:**
```bash
curl -X POST http://localhost:4444/api/pairing/start
# {"ok":true,"session_id":"...","confirm_code":"ABC-123","pairing_url":"...","expires_in":600}
```

**Check status:**
```bash
curl http://localhost:4444/api/pairing/status
# {"ok":true,"status":"pairing","session_id":"...","confirm_code":"ABC-123",...}
```

**Cancel pairing:**
```bash
curl -X POST http://localhost:4444/api/pairing/cancel
# {"ok":true,"status":"cancelled"}
```

**Get identity with pairing status:**
```bash
curl http://localhost:4444/identity
# {"ok":true,"mri":"mri:agent:...","realm":"io.macula","pairing_status":"idle",...}
```

### Verification

- `rebar3 compile` ✅
- `rebar3 eunit` ✅ (61 tests pass)

### Notes

- `hecate_pairing.erl` already had the core pairing logic (gen_server with session management)
- API handler simply exposes the existing `start_pairing/0`, `get_status/0`, `cancel/0` functions
- Identity endpoint gracefully handles missing pairing service (returns `"unknown"` status)

---

## 2026-02-04 COMPLETE [daemon]: Remove hecate_mesh_publisher (Horizontal God Module)

### The Violation

`hecate_mesh_publisher` was a **central dispatcher** — horizontal thinking. Each domain already has its own emitters (e.g., `capability_announced_v1_to_mesh.erl`), but they were delegating to this central module which:

1. Mapped event types to topics (centralized routing table)
2. Called `hecate_mesh_client:publish/2`

This violates vertical slicing: each emitter should own its topic and publish directly.

### The Fix

**1. Refactored all 11 emitters** to call `hecate_mesh_client:publish/2` directly with their own topics:

| Emitter | Topic |
|---------|-------|
| `capability_announced_v1_to_mesh` | `hecate.capability.announced` |
| `capability_updated_v1_to_mesh` | `hecate.capability.revised` |
| `capability_retracted_v1_to_mesh` | `hecate.capability.retracted` |
| `identity_registered_v1_to_mesh` | `hecate.identity.registered` |
| `identity_updated_v1_to_mesh` | `hecate.identity.updated` |
| `agent_followed_v1_to_mesh` | `hecate.social.followed` |
| `agent_unfollowed_v1_to_mesh` | `hecate.social.unfollowed` |
| `capability_endorsed_v1_to_mesh` | `hecate.social.endorsed` |
| `endorsement_revoked_v1_to_mesh` | `hecate.social.endorsement_revoked` |
| `subscribed_v1_to_mesh` | `hecate.subscription.subscribed` |
| `unsubscribed_v1_to_mesh` | `hecate.subscription.unsubscribed` |
| `capability_granted_v1_to_mesh` | `hecate.ucan.granted` |
| `capability_revoked_v1_to_mesh` | `hecate.ucan.revoked` |

**2. Deleted:**
- `apps/hecate_mesh/src/hecate_mesh_publisher.erl`

**3. Updated:**
- `hecate_mesh_sup.erl` — removed hecate_mesh_publisher child
- `hecate_mesh.app.src` — removed from registered list
- `hecate_mesh.erl` — updated facade to delegate to `hecate_mesh_client` directly

**4. Also cleaned up LLM-specific projections (no longer needed):**
- Deleted `llm_capability_subscriber.erl`
- Deleted `llm_capability_announced_v1_to_capabilities.erl`
- Deleted `llm_capability_retracted_v1_to_capabilities.erl`
- Deleted `llm_status_updated_v1_to_capabilities.erl`
- Updated `query_capabilities_sup.erl` to remove llm_capability_subscriber

### Verification

- `rebar3 compile` ✅

### Lesson Learned

Central dispatchers are **horizontal thinking**. Each domain/slice should:
- Own its mesh topic
- Publish directly via `hecate_mesh_client`
- NOT delegate to a "publisher" or "dispatcher" module

---

## 2026-02-04 COMPLETE [daemon]: All 8 Phase 2 Follow-Up Tasks

### Summary

Completed all 8 next steps in order. Test count went from 61 → 85.

### Tasks Completed

| # | Task | Key Deliverable |
|---|------|----------------|
| 73 | Rich Metadata | Hardware config under `{hecate, [{hardware, #{...}}]}`, model/hardware/status sub-maps in announcements |
| 74 | LLM Heartbeat | `report_llm_status` gen_server polls Ollama `/api/ps` every 30s |
| 75 | Latency Measurement | `measure_remote_latency` gen_server pings discovered agents, updates SQLite |
| 76 | Test Coverage | 11 new tests for events, exports, PMs (61 → 72) |
| 77 | RPC Wiring | Already fully wired — verified and confirmed |
| 78 | Mesh Facade | Added `subscribe/2` and `unsubscribe/1` to `hecate_mesh.erl` |
| 79 | UCAN Validation | MRI format validation, resource URI validation, actions allowlist, revoker authority check (72 → 85 tests) |
| 80 | Bootstrap Docs | `guides/BOOTSTRAP_FLOW.md` + `assets/bootstrap-flow.svg` |

### UCAN Validation Details (GitHub Issue #4)

Enhanced `maybe_grant_capability.erl`:
- Issuer/audience must be `mri:agent:*` or `did:*`
- Resource must be `mri:*`, `urn:*`, `https://*`, or `http://*`
- Actions validated against allowlist: `read`, `write`, `execute`, `admin`, `delegate`, `invoke`, `subscribe`

Added revoker authority check in `ucan_aggregate.erl`:
- Only original issuer can revoke a capability
- Returns `{error, not_authorized_to_revoke}` otherwise

### Dialyzer Fixes

Fixed 2 dialyzer warnings:
1. `maybe_grant_capability.erl:97` — removed unreachable `validate_actions(_)` catch-all clause
2. `ucan_aggregate.erl:56` — extracted revoker from Payload map instead of calling through opaque type

### Verification

- `rebar3 eunit` ✅ **85 tests passed**
- `rebar3 dialyzer` ✅ **Clean**

---

## 2026-02-04 COMPLETE [daemon]: serve_llm Refactor + Process Managers

### Summary

Completed the full refactoring of `serve_llm` to proper Cartwheel architecture with Process Managers for cross-domain integration.

### serve_llm Structure (Final)

```
apps/serve_llm/src/
├── detect_llms/                    # Polls Ollama, emits detection events
│   ├── detect_llms.erl
│   ├── llm_detected_v1.erl
│   └── llm_removed_v1.erl
├── chat_to_llm/                    # Handles chat requests
│   ├── chat_to_llm.erl             # Ollama HTTP client (sync + stream)
│   └── chat_to_llm_responder.erl   # Mesh responder
├── list_available_llms/            # Handles list requests
│   ├── list_available_llms.erl
│   └── list_available_llms_responder.erl
├── check_llm_health/               # Handles health requests
│   ├── check_llm_health.erl
│   └── check_llm_health_responder.erl
├── serve_llm_app.erl
└── serve_llm_sup.erl
```

### manage_capabilities Process Managers (New)

```
apps/manage_capabilities/src/
├── on_llm_detected_announce_capability/
│   └── on_llm_detected_announce_capability.erl
└── on_llm_removed_retract_capability/
    └── on_llm_removed_retract_capability.erl
```

**Flow:**
1. `detect_llms` polls Ollama → emits `llm_detected_v1` to `serve_llm_store`
2. Process Manager subscribes → dispatches `announce_capability_v1` to `manage_capabilities`
3. Existing `capability_announced_v1_to_mesh` emitter publishes to mesh

### Deleted (Horizontal/Duplicate)

| File | Reason |
|------|--------|
| `hecate_mesh_publisher.erl` | Central dispatcher (horizontal) |
| `llm_capability_subscriber.erl` | LLM-specific projection (use generic) |
| `llm_capability_announced_v1_to_capabilities.erl` | LLM-specific projection |
| `llm_capability_retracted_v1_to_capabilities.erl` | LLM-specific projection |
| `llm_status_updated_v1_to_capabilities.erl` | LLM-specific projection |
| `handle_llm_rpc_tests.erl` | Tests for deleted modules |
| `llm_backend_tests.erl` | Tests for deleted modules |

### Updated (API Changes)

| File | Change |
|------|--------|
| `hecate_api_llm.erl` | Uses `chat_to_llm`, `list_available_llms`, `check_llm_health` |
| All 11 emitters | Call `hecate_mesh_client:publish/2` directly (not via publisher) |

### Verification

- `rebar3 eunit` ✅ **61 tests passed**
- `rebar3 dialyzer` ✅ **Clean**

### Architecture Lessons Reinforced

1. **No central dispatchers** — each emitter owns its topic
2. **Process Managers for cross-domain** — loose coupling via event subscription
3. **LLM capabilities ARE capabilities** — use existing infrastructure with `type = <<"llm">>`
4. **Each responder in its slice** — Cartwheel architecture

---
