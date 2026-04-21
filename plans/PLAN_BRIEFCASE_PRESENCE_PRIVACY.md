# Plan: Briefcase — Presence + Privacy Refactor

**Status:** Planning
**Created:** 2026-04-21
**Supersedes:** sections of `PLAN_BRIEFCASE.md` (Event Vocabulary, Key Decisions, Integration with hecate-web, Phases 2–5). Cross-references `PLAN_BRIEFCASE.md` for unchanged fundamentals (CMD/PRJ/QRY trinity, relay-only transport, BLAKE3 content addressing, per-file aggregate boundary).

---

## Why this plan exists

`PLAN_BRIEFCASE.md` Phase 1 scaffold shipped with one coarse UX split: `Realm Synced` (event-sourced) vs `Local Scratch` (Tauri-FS-only, no events). That split doesn't map to the real domain — users actually want a **presence axis** and a **privacy axis**, and sharing a file should be an explicit action, not a tab choice.

This plan replaces the tab model with a unified state model anchored in the existing license domain.

---

## State model — two axes, one store

A briefcase file lives in one state at a time across **presence × privacy**:

| State | Bytes on disk | FACT on mesh | Encryption | Source |
|---|---|---|---|---|
| `local + private` | yes, plain | no | none | uploaded here, not shared |
| `local + shared` | yes, plain | yes (metadata FACT) | none on disk, ciphertext-on-serve | uploaded here, published |
| `remote + placeholder` | no — metadata only | yes | n/a | peer announced, no license yet OR license present but not pulled |
| `remote + cached` | yes, `.enc` | yes | on disk + decrypt-on-use | pulled via license |

Invariants:

- Every row in the unified read model has a clear state derivable from two flags: `presence ∈ {local, remote}`, `privacy ∈ {private, shared}` (remote is always `shared` by definition — you can only see something somebody else shared).
- A file moves between states via explicit commands. Files do not drift.
- `Local Scratch` (Tauri-FS-only) is retired. Existing `$lib/stores/briefcase.ts` code is removed.

---

## Event vocabulary — additions + semantic changes

Existing (from `PLAN_BRIEFCASE.md`, unchanged):

- `file_uploaded_v1` — you put a file in your briefcase. **Defaults to `private`.**
- `file_revised_v1`, `file_moved_v1`, `file_archived_v1`, `file_purged_v1`, `folder_*_v1` — unchanged.

New (this plan):

- `file_shared_v1` — you publish a local private file to the realm. Emits a mesh FACT `io.macula.briefcase.file_shared` (metadata only, no content). Triggers license issuance.
- `file_unshared_v1` — you revoke sharing. Revokes the license. Peers' placeholders get a `revoked` state.
- `file_announced_v1` — your daemon received a `file_shared` FACT from a peer. Creates a `remote + placeholder` row.
- `file_cached_v1` — your daemon pulled + cached a remote file's content (encrypted). Row flips to `remote + cached`.
- `file_evicted_v1` — user evicted the cache; row flips back to `remote + placeholder`. License stays valid.

License domain events (already exist in `guide_license_lifecycle`, new usage here):

- `license_issued_v1` — Alice issues license to Bob or to realm. Carries wrapped CEK.
- `license_accepted_v1` — Bob's daemon receives + stores (wraps for his own at-rest key).
- `license_revoked_v1` — Alice revokes. Bob's daemon marks CEK unusable; future `open` refuses.

"Access granted/revoked" events from `PLAN_BRIEFCASE.md` are absorbed into the license domain rather than duplicated in briefcase.

---

## Storage topology

```
$HECATE_HOME/hecate-daemon/briefcase/content/
├── local/{XX}/{FileId}.bin        # your files, plain bytes
└── cache/{XX}/{FileId}.enc        # remote files, encrypted with CEK
```

Key points:

- Local and cache are distinct subtrees — a FileId cannot appear in both. (If you originated it, it's `local`; you don't need a cache entry.)
- Cache files are never written plain. Decryption happens in the daemon process, in memory, stream-by-stream.
- `.enc` file format: `[nonce:24] [ciphertext+tag]` using XChaCha20-Poly1305 (same AEAD as `PLAN_BRIEFCASE.md` Phase 4).
- BLAKE3 content-address unchanged.

---

## Encryption model — license-based

Drives Q1 decision (realm shared key + per-recipient pubkey wrap).

### Per-file Content Encryption Key (CEK)

On `file_shared_v1`:

1. Alice's daemon generates a fresh 256-bit CEK.
2. Encrypts the `local/{XX}/{FileId}.bin` bytes into an ephemeral ciphertext blob for serving (no on-disk re-encryption — local plaintext stays). Alternative: derive ciphertext on-demand per serve (streaming encrypt). **Preferred: on-demand streaming encrypt** per fetch, so the CEK isn't unnecessarily serialized to disk on the origin.
3. Wraps the CEK based on license target:
   - **License to realm** → wrap CEK once with the realm shared symmetric key.
   - **License to Bob (specific DID)** → wrap CEK with Bob's public key.
4. Issues a `license_issued_v1` event carrying `{wrapped_cek, grantee, file_id, terms}`.
5. Publishes `file_shared_v1` FACT (metadata only — file_id, path, size, mime, content_hash — no CEK).

### Peer receiving the FACT

1. Bob's daemon gets `file_shared` FACT → dispatches `file_announced_v1`.
2. If license present (arrived via `license_issued_v1` either in the same mesh flow or earlier), Bob unwraps CEK using (his private key | realm shared key) and stores CEK alongside the placeholder.
3. If no license, row is `placeholder + locked` — Bob can see it exists but can't pull/decrypt until/if Alice issues one.

### On `open`

1. hecate-web requests `GET /api/briefcase/files/{id}/content`.
2. Daemon path:
   - `local + *` → stream plaintext from `local/{XX}/{FileId}.bin`.
   - `remote + cached` → stream ciphertext from `cache/{XX}/{FileId}.enc`, decrypt chunk-by-chunk with CEK, stream plaintext over Unix socket.
   - `remote + placeholder` → 404 or auto-pull (see Phase E below).
3. CEK never leaves the daemon process. hecate-web only sees plaintext bytes.

### Realm shared key — delivered by macula-realm (resolved 2026-04-21)

Investigation confirmed no realm-wide shared symmetric key exists today. The
realm today is an identity set (`realm_membership_confirmed_v1` carries
identity only; `hecate_crypto` encrypts at rest with the **Erlang cookie**,
which is cluster-local, not realm-scoped).

**Resolution:** macula-realm server mints `K_realm` at realm-creation and
delivers it to each joining daemon over TLS. Piggy-backed on the existing
gitops-provisioning RPC (or a dedicated `realm.get_shared_key` call).
Operator-controlled rotation via the realm server.

Daemon stores `K_realm` encrypted at rest using existing `hecate_crypto`
(AES-256-GCM + Erlang-cookie-derived key). Daemon-local, never leaves the
daemon process.

### Grantee identity in the license — realm MRI

License event payload identifies the grantee as either:

- A specific DID (e.g., `did:macula:bob`) → wrapped CEK uses Bob's pubkey
- The **realm MRI** (e.g., `mri:realm:io.macula`) → wrapped CEK uses `K_realm`

For realm-licenses, membership is implicit via possession of the current
`K_realm`. New members joining later inherit access to historical
realm-licensed files on catching up the license topic. Members who left
lose future access via rotation (below).

Licenses are **unbounded** by default; the `expires_at` field exists on the
aggregate but stays `null` for v1. Time-bounded grants + renewal machinery
are a later phase when the use case appears.

### License topic

License events flow on their own dedicated mesh topic, not piggy-backed on
briefcase FACTs:

- `{realm}.licenses.issued` — publishes `license_issued_v1` (carries wrapped CEK)
- `{realm}.licenses.revoked` — publishes `license_revoked_v1`
- `{realm}.licenses.rewrapped` — publishes `license_rewrapped_v1`

Other realm-scoped domains (scribe, stage, martha, meshtube) reuse the same
license domain; owning the topic separately keeps the license bounded
context reusable. Ordering with the `briefcase.file_shared` topic is not
guaranteed — UI handles both orderings gracefully (placeholder+metadata-
missing vs placeholder+locked).

### Revocation + rotation semantics

- `license_revoked_v1` → daemon marks the CEK record unusable. Subsequent
  `open` returns `403 license_revoked`. Cached ciphertext stays on disk
  (harmless without the CEK) until user clicks `Evict` or purges.
- Already-decrypted-in-memory bytes in a peer's browser at revocation time:
  out of scope. Soft boundary (Q2).
- **Realm key rotation on member-leave**: automatic on every
  `realm_membership_revoked_v1` event. Rotate `K_realm` → re-wrap all
  active licenses' CEKs (no content re-encryption). Via process manager
  pattern — see below.

### Process manager wiring

Two `on_*` process managers connect realm-level events to license-level
effects. Both directories scream at the filesystem level, matching the
architectural rule in hecate-daemon/CLAUDE.md.

```
realm_membership_revoked_v1  (guide_realm_memberships)
  ↓
apps/guide_realm_memberships/src/on_realm_membership_revoked_rotate_key/
  → dispatches rotate_realm_key_v1 command to macula-realm server
    ↓
realm_key_rotated_v1          (guide_realm_memberships or new domain)
  ↓
apps/guide_license_lifecycle/src/on_realm_key_rotated_rewrap_licenses/
  → for each active license in the realm:
      dispatches rewrap_license_v1
        ↓
      license_rewrapped_v1     (guide_license_lifecycle)
        ↓
      emitter publishes to {realm}.licenses.rewrapped topic
```

License aggregate state after a rewrap:

```erlang
#{license_id       => ...,
  grantee          => ...,                % realm MRI or DID
  file_id          => ...,
  wrapped_cek      => <latest wrapped bytes>,
  k_realm_version  => <integer>,          % which key version wrapped this
  rewrap_count     => <integer>,          % observability
  status           => active | revoked,
  expires_at       => null | <integer>,   % null in v1
  ...}.
```

**Catch-up lag:** if Bob is offline when Carol is revoked, rotation happens
without him. On reconnect, Bob must fetch the current `K_realm` version
from macula-realm before any of his licenses unwrap. Phase C includes a
startup/reconnect check: compare local `K_realm` version to realm server's
current version, pull updates before using.

---

## UI — single list with filter chips

Drives Q5 decision.

Route `/briefcase` in hecate-web. Single table, top bar with filters:

```
Briefcase
────────────────────────────────────────────────────────────
[All] [Mine] [From realm] [Cached] [Shared] [Private]
────────────────────────────────────────────────────────────
report.pdf   [Shared]                 14 KB   just now   [Unshare] [Delete]
draft.md     [Private]                 8 KB   2h ago     [Share to realm] [Delete]
alice-pic.jpg [From realm, cached]    82 KB   3d ago     [Open] [Evict]
bob-notes.txt [From realm, placeholder]  —    1h ago     [Download]
```

Row-level actions driven by state:

| State | Actions |
|---|---|
| `local + private` | `Share to realm`, `Delete` |
| `local + shared` | `Unshare`, `Delete` |
| `remote + placeholder` | `Download` |
| `remote + cached` | `Open`, `Evict` |

Viewstate pattern: daemon computes row-level `state`, `badges[]`, `actions[]`; frontend is a pure renderer. Matches `feedback_viewstate_pattern.md`.

Retires:
- `Realm Synced / Local Scratch` tabs.
- `$lib/stores/briefcase.ts` (Tauri-FS-only store). Delete the file.
- `$lib/stores/briefcase-realm.ts` becomes `$lib/stores/briefcase.ts` (single source).
- `BriefcaseRealm.svelte` rolls into `Briefcase.svelte`.

---

## Phased implementation

Phases are independently ship-able. Each ends with a working app.

### Phase A — Unified model on existing storage (no crypto yet)

**Goal:** single event-sourced store, retire Tauri-FS tab, fix the "file never rendered" bug.

- Add `privacy` flag to `file_uploaded_v1` payload (default `private`).
- New events: `file_shared_v1`, `file_unshared_v1` (CMD + handlers + projection updates).
- Extend `project_briefcase_files_store` read model with `privacy` column.
- Retire `$lib/stores/briefcase.ts`; delete `Local Scratch` tab.
- Single `Briefcase.svelte` with filter chips.
- **Fix the "nothing renders" bug**: optimistic UI prepend in `uploadRealmFile` using the upload response; projection refresh lands behind.
- No mesh FACTs emitted yet — `Share to realm` is a no-op flag flip until Phase B.

**Done when:** user can upload (private), toggle private→shared (locally, no mesh), filter chips work, upload→file-appears-immediately.

### Phase B — Mesh announcement (no content transfer yet)

**Goal:** peers see each other's placeholders.

- On `file_shared_v1`, emitter publishes `io.macula.briefcase.file_shared` FACT (metadata only).
- Mesh listener `listen_for_shared_files` (already exists) dispatches `file_announced_v1` on receive.
- Read model gains `remote + placeholder` rows.
- UI shows placeholders with `Download` button — button is disabled / says "coming in Phase E".

**Done when:** Alice shares locally, Bob's UI shows the placeholder row within seconds.

### Phase C — Realm shared key infrastructure

**Goal:** build the realm shared key distribution (confirmed new work — see "Realm shared key" section above).

- macula-realm server: add `K_realm` minting at realm creation; persist encrypted with operator admin key.
- macula-realm RPC: `realm.get_shared_key(Realm) → {ok, #{version, key}}` (TLS-protected; authenticated via user's Hanko session).
- hecate-daemon: on realm-join, call the RPC, store `K_realm` locally via `hecate_crypto` (AES-256-GCM at rest).
- New module `hecate_realm_crypto` exposing: `realm_key(Realm) → {ok, {Version, Key}} | {error, not_joined}`; `rotate_realm_key(Realm)` (triggers fetch from server); `unwrap_for_realm(CipherText, Realm)`.
- Process manager: `on_realm_membership_revoked_rotate_key` dispatches rotation via realm server RPC; receives `realm_key_rotated_v1` event with new version.
- Process manager: `on_realm_key_rotated_rewrap_licenses` iterates active licenses in the realm, dispatches `rewrap_license_v1` commands.
- Catch-up: on daemon startup + realm-reconnect, compare local `K_realm` version to realm server; pull updates.

**Done when:** daemon can fetch `K_realm` at join; rotation-on-revoke round-trips through both PMs; Bob offline during rotation catches up on reconnect.

### Phase D — License-based CEK for shared files

> **Detailed plan lives in `PLAN_PHASE_D_LICENSING.md`** — all open questions
> resolved there (DID-scope first-class, rewrap-on-rotation, `expires_at`
> 10-year horizon, distinct revoke/resign events, batched license mesh
> events). The summary below is the parent plan's framing; the detailed
> doc supersedes it on specifics.

**Goal:** encryption on the serve path; licenses carry wrapped CEKs.

- `file_shared_v1` handler generates fresh CEK, wraps it for the license target (realm key or recipient pubkey), dispatches `license_issued_v1`.
- `license_accepted_v1` on the receiving side unwraps + stores CEK.
- Serve path (not yet on-demand — just test encrypt/decrypt round-trip via unit test).

**Done when:** `license_issued_v1 → license_accepted_v1` round-trip works, CEK unwrap verifies, revocation marks CEK unusable.

### Phase E — Remote pull + cache

**Goal:** Bob can click Download and get the file.

- Pull: `briefcase.get_content_stream` RPC (preferred: use macula 1.5.2 streaming primitives; `PLAN_MACULA_STREAMING.md` Phase 4). Ciphertext-encrypted on the serve side using CEK.
- Bob's daemon writes stream to `cache/{XX}/{FileId}.enc`.
- Dispatches `file_cached_v1`; read model flips to `remote + cached`.
- `Evict` action deletes the `.enc` file; dispatches `file_evicted_v1`.

**Done when:** Alice shares → Bob downloads → Bob's cache has encrypted file → Bob can evict.

### Phase F — Decrypt-on-use serve to hecate-web

**Goal:** Open button works; plaintext never lands on disk on Bob's side.

- `GET /api/briefcase/files/{id}/content` in daemon: streams decrypted bytes over Unix socket for `remote + cached` rows.
- Chunk-wise streaming decrypt — no full-file buffering.
- WebKit renders the stream (image/pdf/text — standard browser rendering).
- No plaintext caching headers; `Cache-Control: no-store`.

**Done when:** Bob clicks Open on a cached remote file → content renders in hecate-web → no plaintext file exists on Bob's disk.

---

## Success criteria (all phases)

- [ ] Single unified read model (`briefcase_files` ETS) covers all 4 states
- [ ] `$lib/stores/briefcase.ts` (Tauri-FS scratch) deleted; no dead code
- [ ] `Local Scratch` tab removed from hecate-web nav
- [ ] Click-upload → file appears in list within same animation frame (optimistic) or ≤50ms (projection-backed)
- [ ] Alice shares → Bob's placeholder appears within the relay RTT
- [ ] Alice revokes → Bob's Open fails with `403 license_revoked`
- [ ] `cache/*.enc` files are ciphertext at rest (grep file_contents → find nothing)
- [ ] Plaintext of remote file never appears on Bob's disk

---

## Resolved decisions (2026-04-21 session)

| # | Question | Decision |
|---|---|---|
| Q1 | Realm shared key today? | No. **macula-realm server mints `K_realm` at realm creation, delivers at join via TLS-authenticated RPC.** Operator controls rotation. |
| Q2 | Rotation on member-leave? | **Automatic on every `realm_membership_revoked_v1`.** Rotate `K_realm`, re-wrap CEKs only (no content re-encryption). Via process manager pattern. |
| Q3 | Where do licenses travel? | **Dedicated mesh topic `{realm}.licenses.{issued,revoked,rewrapped}`.** License domain stays reusable across future consumers. |
| Q4 | Grantee identity? | **Realm MRI** (e.g., `mri:realm:io.macula`) for realm-licenses; **DID** for targeted. New members inherit historical access on key + topic catch-up. Unbounded by default (expires_at = null). |

## Deferred (revisit after v1)

- LRU cache size cap on remote content. User-controlled eviction only in v1.
- Time-bounded license grants + renewal lifecycle.
- License-metadata privacy: who-got-what is visible on the license topic; acceptable for trusted realms; tighten with encrypted-metadata later if needed.
- Cross-realm license delegation.

---

## Cross-references

- `PLAN_BRIEFCASE.md` — overall briefcase plan (still authoritative on: trinity architecture, chunking, BLAKE3, relay-only transport, aggregate boundary).
- `PLAN_MACULA_STREAMING.md` — streaming RPC primitives used in Phase E.
- `feedback_viewstate_pattern.md` — daemon computes presentation; frontend renders.
- `hecate-daemon/apps/guide_license_lifecycle/` — existing license domain, extended for CEK delivery.

---

## Non-goals

- Hard DRM. Soft boundary per Q2.
- Size-capped LRU cache. User-controlled eviction only per Q4.
- Cross-realm sharing. Licenses stay within a single realm's grantee set (realm or DID-in-realm).
- Forward secrecy on revoke. Already-decrypted plaintext in a peer's RAM is out of scope.
