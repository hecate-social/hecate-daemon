# Plan: Hecate Briefcase — Mesh-Backed File Sharing

**Status:** Planning (Phase 0 → Phase 1 scaffold shipped with this PR)
**Created:** 2026-04-20
**Last Updated:** 2026-04-20

---

## Overview

Hecate Briefcase is the **built-in file-sharing capability** of the Hecate
daemon: a decentralized, end-to-end-encrypted, realm-scoped file store with
an "appears everywhere in the realm" UX. It is the **killer app** that
demonstrates Macula's DHT PubSub/RPC primitives doing real work.

Positioned as a Dropbox/Nextcloud replacement that:

- Stores files across realm peers — no central server
- E2E encrypted — the daemon on any peer cannot read foreign content
- Works across home-ISP NATs without port forwarding (QUIC)
- Offline-first; local queue reconciles on reconnect
- Crosses the rebel → SMB audience chasm

**Other Hecate apps (scribe, ledger, stage) consume Briefcase** as their
document storage layer. Briefcase is a capability, not a use case.

---

## Positioning Decision

**Briefcase is built into `hecate-daemon`, not a plugin.**

Reasons:

1. Briefcase is foundational infrastructure — peer to `settings`, `plugins`,
   `realm_memberships`. Not a third-party use-case like `trader` or `martha`.
2. Document apps (scribe, ledger, stage) depend on it. Core capabilities
   don't live in the plugin layer.
3. Storage + crypto + mesh integration operates at the daemon's trust level.

The prior `hecate-apps/hecate-app-briefcase` placeholder repo has been
deleted (was empty scaffold; capability belongs inside the daemon).

---

## Architecture

Three apps following the CMD / PRJ / QRY trinity pattern used across the
rest of `hecate-daemon`:

| App | Department | Purpose |
|---|---|---|
| `guide_briefcase_lifecycle` | CMD | Commands, events, aggregate, chunk store, crypto, mesh emitters |
| `project_briefcase_files` | PRJ | Event-to-read-model projections (file tree + chunk index) |
| `query_briefcase_files` | QRY | HTTP API — `GET /api/briefcase/...` |

### Mesh primitives used

- **PubSub** topic `briefcase/realm/{realm}/events` — event log broadcast
- **RPC** procedures `briefcase.get_chunk`, `briefcase.has_chunk`,
  `briefcase.list_chunks`
- **DHT** — chunk-to-peer location hints
- **Realm** — trust boundary
- **UCAN / DID** — capability grants for cross-realm sharing
- **QUIC** — NAT traversal built-in

### Storage

- **Event log**: ReckonDB stream `briefcase-{realm}`
- **Read model**: SQLite, projected from events
- **Chunks**: content-addressed on disk,
  `$HECATE_HOME/briefcase/chunks/{blake3[:2]}/{blake3}.enc`

---

## Key Technical Decisions

| Decision | Choice | Why |
|---|---|---|
| Content hashing | BLAKE3 | Already in stack via `macula_blake3_nif`; fast, tree-hashable |
| Chunk size (v1) | Fixed 1 MiB | Simple; FastCDC later |
| Encryption | XChaCha20-Poly1305 per chunk | AEAD, no nonce-reuse footguns |
| Key derivation | HKDF-SHA256; per-realm master → per-file key | Lazy rotation, capability-friendly |
| Signatures | Ed25519 via existing DID keys | Already in stack |
| Conflict resolution (v1) | LWW with wallclock + peer-id tiebreaker | Ship fast; upgrade to CRDT if needed |
| Replication (v1) | Full within realm | Predictable; erasure coding is Phase 5 |
| Transport | Mesh RPC (QUIC under hood) | NAT traversal included |
| Local truth model (v1) | API-only; no sync folder | No reconciler complexity upfront |
| Local truth model (v6) | Event-sourced with FS reconciler | Dropbox-style UX once correctness is solid |

---

## Event Vocabulary

All business-verb past-tense, following project naming conventions (no
CRUD verbs):

- `file_uploaded` — first appearance
- `file_revised` — new version (not "updated")
- `file_moved` — path change
- `file_archived` — soft delete, tombstone, recoverable
- `file_purged` — hard delete, chunks GCable
- `folder_opened` — folder created
- `folder_collapsed` — folder removed
- `access_granted` — UCAN issued for subject DID
- `access_revoked`
- `chunk_transfer_started` / `_completed` / `_cancelled`
- `chunk_landed` — a peer acquired a chunk (DHT hint)

Every event carries: `realm`, `subject_did`, `wallclock`, `vector_clock`,
`parent_event_id`.

---

## RPC Surface (v1)

```
briefcase.list_chunks(path_or_file_id) -> [BlakeHash]
briefcase.has_chunk(BlakeHash)         -> bool
briefcase.get_chunk(BlakeHash)         -> bytes        (realm-scoped, signed)
briefcase.request_chunk(BlakeHash)     -> stream
briefcase.seed_chunk(BlakeHash, bytes) -> ok           (backup-only peers)
```

Small, stable surface. This is the client contract across web / CLI /
editor-plugins / MCP.

---

## Phased Roadmap

| Phase | Weeks | Output | Status |
|---|---|---|---|
| 0. Discovery + decisions | 1 | Archive `hecate-app-briefcase`; decide Option A/B/C; draft event vocabulary | ✅ Done |
| 1. Skeleton trinity | 2–4 | `guide_briefcase_lifecycle` + `project_briefcase_files` + `query_briefcase_files` scaffolded; `upload_file` works end-to-end; whole-file storage; no mesh yet | ⏳ Scaffold in this PR |
| 2. Mesh distribution | 5–7 | PubSub for events; RPC `briefcase.get_chunk`; full-file replication across realm peers | 📋 |
| 3. Chunking + dedup | 8–10 | BLAKE3 1-MiB chunks; content-addressed store; parallel multi-peer fetch; resume | 📋 |
| 4. E2E encryption | 11–13 | Per-realm key; per-file HKDF-derived keys; XChaCha20-Poly1305 | 📋 |
| 5. UCAN sharing | 14–16 | External share links; time-bounded capability grants; revocation | 📋 |
| 6. Native sync folder | 17–21 | Reconciler between events and `$HECATE_HOME/briefcase/realm/{r}/`; FS watcher | 📋 |
| 7. Replication policy | 22–26 | Tunable per-folder replication; LAN peer affinity; quotas; backup-only peers | 📋 |

---

## Files to Create / Modify (Phase 1 Scaffold)

| File | Purpose | Status |
|---|---|---|
| `apps/guide_briefcase_lifecycle/src/guide_briefcase_lifecycle.app.src` | App manifest | ✅ |
| `apps/guide_briefcase_lifecycle/src/guide_briefcase_lifecycle_app.erl` | App entry | ✅ |
| `apps/guide_briefcase_lifecycle/src/guide_briefcase_lifecycle_sup.erl` | Top supervisor | ✅ |
| `apps/guide_briefcase_lifecycle/include/briefcase_state.hrl` | State record | ✅ |
| `apps/guide_briefcase_lifecycle/include/briefcase_status.hrl` | Status bit flags | ✅ |
| `apps/guide_briefcase_lifecycle/src/briefcase_state.erl` | State module | ✅ |
| `apps/guide_briefcase_lifecycle/src/briefcase_aggregate.erl` | Aggregate | ✅ |
| `apps/guide_briefcase_lifecycle/src/upload_file/upload_file_v1.erl` | Command | ✅ |
| `apps/guide_briefcase_lifecycle/src/upload_file/file_uploaded_v1.erl` | Event | ✅ |
| `apps/guide_briefcase_lifecycle/src/upload_file/maybe_upload_file.erl` | Handler | ✅ |
| `apps/project_briefcase_files/src/project_briefcase_files.app.src` | PRJ manifest | ✅ |
| `apps/project_briefcase_files/src/project_briefcase_files_app.erl` | PRJ entry | ✅ |
| `apps/project_briefcase_files/src/project_briefcase_files_sup.erl` | PRJ supervisor | ✅ |
| `apps/project_briefcase_files/src/briefcase_lifecycle_to_files.erl` | Projection | ✅ |
| `apps/query_briefcase_files/src/query_briefcase_files.app.src` | QRY manifest | ✅ |
| `apps/query_briefcase_files/src/query_briefcase_files_app.erl` | QRY entry | ✅ |
| `apps/query_briefcase_files/src/get_files_page/get_files_page_api.erl` | HTTP read endpoint | ✅ |

Further verb slices (`revise_file`, `move_file`, `archive_file`,
`purge_file`, `open_folder`, `collapse_folder`, `grant_access`,
`revoke_access`, chunk-transfer verbs) follow in subsequent PRs per phase.

---

## Open Questions (Resolve Before Phase 2)

1. **Realm master key storage** — passphrase-derived? TPM-backed?
   Shamir secret sharing across trusted peers? Decide before Phase 4.
2. **Aggregate boundary** — per-file aggregate or per-realm-filesystem
   aggregate? Per-file = simpler; per-realm = stronger consistency.
   Phase 1 scaffold uses **per-file aggregate** (file_id as stream).
3. **Do existing `scribe` / `ledger` / `stage` apps already assume a
   storage contract?** If yes, match it. If no, Briefcase defines it.
4. **Metadata privacy** — encrypted chunks, but the event log exposes
   paths / sizes / timestamps. Encrypt events themselves? Traffic-analysis
   resistance is a Phase 6+ decision.
5. **Quota enforcement** — per-user, per-realm, per-peer? Decentralized
   enforcement is hard. Each peer enforcing its own quota is the simplest
   v1 answer.

---

## Success Criteria (Phase 1)

- [x] Three apps compile clean (`rebar3 compile --deps_only && rebar3 compile`)
- [ ] `upload_file` command dispatches successfully through
      `reckon_evoq_adapter` to `briefcase_store` (new ReckonDB store)
- [ ] `file_uploaded_v1` event appears in the event log
- [ ] `briefcase_lifecycle_to_files` projection updates the
      `briefcase_files` ETS table
- [ ] `GET /api/briefcase/files` returns the new file
- [ ] No `services/` / `utils/` / `handlers/` horizontal layers created

---

## Non-Goals (v1)

- Rich-text collaborative editing (Figma/Notion territory — out of scope)
- Public internet-wide file sharing (realm-scoped; external = via UCAN)
- Mobile clients (desktop + web first)
- POSIX FUSE mount
- Real-time video (that's the future Calls app, separate)

---

## Integration with `hecate-web`

Current state: `hecate-web`'s Briefcase tab reads `$HECATE_HOME/briefcase/`
directly via Tauri's FS plugin — **local-only, no event sourcing, no sync**.

**Migration path**:

- **Phase 1**: add a toggle in the Briefcase store: "Local scratch" (existing
  Tauri FS code, unchanged) vs. "Realm synced" (new, calls
  `query_briefcase_files` via `hecate-api`)
- **Phase 6**: `guide_briefcase_lifecycle` grows a reconciler that
  materializes `$HECATE_HOME/briefcase/realm/{r}/` from events. Existing
  Tauri code keeps working; files appear in the folder automatically.

No breaking changes to `hecate-web` at any phase.

---

## Marketing Surface

Demo script (<2 minutes):

1. Install Hecate on 3 laptops via `hecate-install`
2. Drop `report.pdf` onto Briefcase tab on Laptop 1
3. Watch it appear in Laptop 2's and Laptop 3's Briefcase within seconds
4. Unplug Laptop 2 from Wi-Fi; file still opens locally
5. Connect Laptop 3 to a hotel Wi-Fi behind NAT; still syncs
6. Inspect disk on any peer: `grep` the file contents — find nothing

Tagline candidate: *"Dropbox, but no one drops anything on anyone's server."*
