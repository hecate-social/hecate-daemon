# Plan: Phase D — License-based CEK + Identity Pubkeys + Rewrap

**Status:** Planning
**Created:** 2026-04-22
**Scope:** Extends `PLAN_BRIEFCASE_PRESENCE_PRIVACY.md` Phase D. Cross-repo: `hecate-daemon`, `macula-realm`.
**Depends on:** Phase C.2 shipped (K_realm mint/fetch/seal pipeline + `hecate_realm_crypto`).

---

## Why this plan exists

Phase C.2 landed the realm-scope crypto primitive — every member can fetch a
sealed `K_realm` and use `hecate_realm_crypto:wrap/unwrap` to encrypt payloads
for the realm. Phase D builds the **license domain** on top of that primitive:

- A share action mints a per-file Content Encryption Key (CEK).
- The CEK is wrapped under the grantee's cryptographic root — `K_realm` for
  realm-scope grants, the grantee's X25519 pubkey for DID-scope grants.
- The wrapped CEK travels on a dedicated license mesh topic, is caught up on
  reconnect (missed license issuance/revocation cannot silently vanish), and
  is re-wrapped when `K_realm` rotates.
- Phase D is Phase E's prerequisite: content transfer is useless without a
  license negotiation that grants the decryption key.

Phase D also shakes out the secondary infrastructure pieces that Phase C.2
defer'd — identity encryption pubkeys, a mesh-wide license-event replay
source, and the staleness guard that gates `open` against stale knowledge.

---

## Resolved decisions

| # | Question | Decision |
|---|---|---|
| D1 | Realm-scope only, or include DID-scope? | **Both.** DID-scope is first-class — sharing with specific people is basic functionality, not a follow-up. |
| D2 | Revocation semantics (cached plaintext, in-RAM bytes)? | As in PLAN_BRIEFCASE_PRESENCE_PRIVACY Q2 — mark CEK unusable on revoke, cached ciphertext stays (harmless without CEK), already-decrypted plaintext out of scope. |
| D3 | License `expires_at` default? | `issued_at + 10 years`. Forces the field to always exist, sets social expectation that licenses expire, gives renewal machinery a real slot for later. No `null`. |
| D4 | Catch-up mechanism? | First-class. Realm server tails `{realm}.licenses.*` topics, persists to a new `{realm}_licenses_store`, advertises `io.macula.licenses.replay_events_v1` RPC. Daemons catch up on reconnect. |
| D5 | Eager or lazy CEK unwrap on accept? | **Eager.** Accept handler unwraps immediately and stores plaintext CEK sealed via `hecate_crypto`. Makes rewrap-on-rotation audit-only for recipients. |
| D6 | Revoked vs. resigned — distinct or one event with reason? | **Distinct.** `revoke_realm_membership_v1` (admin authority, realm-server side) and `resign_realm_membership_v1` (member authority, daemon side). Different authorization, different social contract, different audit. |
| D7 | Do both trigger K_realm rotation? | **Yes.** Forward secrecy demands it. Revoke fires immediate rotation; resign fires debounced rotation (60s window). Rotation is owned by the realm server. |
| D8 | Daemon-side membership terminal verb? | **`end_realm_membership`** (not `revoke`, not `amend`). Parameterized by `reason: :revoked \| :resigned \| :banned`. `amend_realm_membership` reserved for future non-terminal changes. |
| D9 | Wrap key combination `K_wrap = f(K_realm, K_DID)`? | **No.** Gives defense-in-depth but doesn't reduce N wraps. Keep K_realm and K_DID orthogonal. |
| D10 | O(N) wrap cost mitigation? | **Batch license events on the mesh.** One `licenses_issued_batch_v1` publish per share, N per-recipient entries inside. Reduces mesh events O(N)→O(1); wraps stay O(N) (unavoidable). |
| D11 | Staleness guard? | `open`-path refuses license if `now - last_license_catchup > threshold` (default 24h), or `CEK_UNUSABLE` bit set, or `now > expires_at`. |
| D12 | Rotation owner? | Realm server. Membership facts on `{realm}.membership.{revoked,resigned}` trigger realm-server-side `rotate_realm_key_v1` dispatch. |

## Deferred to Phase D.5 / later

- **Suspension + role changes** (non-terminal membership amendments). `amend_realm_membership_v1` desk name reserved.
- **License renewal machinery.** 10-year horizon makes this non-urgent.
- **Time-bounded grants** (short-duration licenses with renewal protocol).
- **Defense-in-depth wrap strategy** (`:did_x25519_with_realm_binding_v1`). Available as an opt-in later if a use case needs two-key compromise resistance.
- **Broadcast / IBE / ABE crypto** for genuine O(1) wraps. Heavy machinery; revisit if realm sizes grow absurdly.
- **Cross-realm license delegation.**
- **Aggregate snapshots** for rewrap-on-rotation (Phase D ships the naïve iterate path; snapshot-assist comes when rewrap time becomes painful).

---

## Architecture overview

### Trust model

| Actor | Holds | Trust role |
|---|---|---|
| Realm server (macula-realm) | `K_realm` plaintext (sealed at rest with SECRET_KEY_BASE) | Authority for `K_realm` minting + rotation. Authority for membership event stream. License event registry (observer, not issuer). |
| Member daemon (hecate-daemon) | Own identity keypair (Ed25519 signing, X25519 encryption). Sealed `K_realm` per joined realm. Sealed plaintext CEKs for files it issued licenses for, AND for licenses it accepted. | Issues licenses for its own shares. Accepts licenses for shares targeting it. Mirrors membership + license authority via catch-up. |
| Relay | Nothing persistent about licenses (just transits pub/sub traffic). | Envelope visibility (topic names, headers). Wrapped CEKs are cryptographic blobs in transit. |

### Data at rest per actor

**Realm server (macula-realm) gains:**
- `{realm}_licenses_store` (reckon_db) — raw append-only log of all license events observed on `{realm}.licenses.*` topics. Primary purpose: replay for reconnecting daemons.
- `{realm}_identities_store` (reckon_db) — registry of DID → X25519 pubkey bindings published by members.

**Member daemon (hecate-daemon) gains:**
- X25519 keypair derived from identity (stored sealed via `hecate_crypto`).
- Per-license record in existing `licenses_store`:
  - For issued licenses: plaintext CEK sealed with `hecate_crypto` (`origin_cek_sealed`) for future rewrap operations.
  - For accepted licenses: plaintext CEK sealed with `hecate_crypto` (`accepted_cek_sealed`) for Phase F open-path.

### Mesh topic inventory

```
{realm}.identity.public_key_announced   — identity pubkey binding
{realm}.membership.resigned             — member-initiated departure
{realm}.membership.revoked              — admin-initiated removal
{realm}.keys.rotated                    — K_realm rotated (new version)
{realm}.licenses.issued_batch           — license grants (batched per share)
{realm}.licenses.revoked                — license revocation (single, realm scope)
{realm}.licenses.rewrapped              — CEK rewrapped under new K_realm
```

Topics registered via `hecate_topics:fact/3` / `hecate_topics:hope/3` (MEMORY reference).

### Replay RPCs (realm server)

```
io.macula.realm.get_member_public_keys     — DID → X25519 pubkey batch lookup
io.macula.licenses.replay_events_v1        — license event replay for daemon catch-up
```

### End-to-end flow (happy path, DID-scope share with N recipients)

```
Alice shares report.pdf with Bob, Carol, Dave.

1. CEK = strong_rand_bytes(32)
2. Alice fetches pubkeys: realm.get_member_public_keys([bob_did, carol_did, dave_did])
3. For each recipient R:
     shared_secret = X25519_ECDH(ephemeral_priv, R_pubkey)
     wrap_key = HKDF(shared_secret)
     wrapped_cek_R = AES-256-GCM(CEK, wrap_key)
4. Alice's briefcase aggregate emits file_shared_v1 (unchanged from Phase B)
5. Alice's license domain:
     - for each recipient: issue_license_v1 command → license_issued_v1 event (local)
     - Alice's licenses_store now has 3 licenses, each with origin_cek_sealed (same CEK, sealed locally)
6. Batched emitter on Alice's daemon:
     licenses_issued_batch_v1 event → single FACT on {realm}.licenses.issued_batch
     carrying entries: [
       {license_id_bob, grantee: did:macula:bob, wrap_strategy: :did_x25519_v1, wrapped_cek: ...},
       {license_id_carol, ...},
       {license_id_dave, ...}
     ]

7. Realm server listens to {realm}.licenses.issued_batch:
     - persists the batch event verbatim to {realm}_licenses_store
     - no per-entry indexing needed; replay is ordered by offset

8. Each recipient's daemon listens to {realm}.licenses.issued_batch:
     - filters entries for own DID
     - dispatches accept_license_v1 for the matched entry
     - handler: unwrap wrapped_cek via hecate_did_crypto:unwrap/2
     - stores plaintext CEK sealed via hecate_crypto (accepted_cek_sealed)
     - license_accepted_v1 event stored locally (not published — private)

9. (Later) Bob reconnects after N hours offline:
     - catch_up_realm_licenses worker calls io.macula.licenses.replay_events_v1
     - receives batch events he missed
     - dispatches accept_license_v1 for each entry matching his DID
     - last_license_catchup timestamp updated per realm

10. Alice revokes Dave's license:
     revoke_license_v1 cmd → license_revoked_v1 (local) → FACT on {realm}.licenses.revoked
     Dave's listener: dispatches end_license_v1 → marks CEK_UNUSABLE bit
     Dave's open-path now returns 403 for that file_id
```

### K_realm rotation flow (rewrap-on-rotation)

```
Scenario: Carol is revoked (admin action).

1. Admin dispatches revoke_realm_membership_v1 on macula-realm
     → realm_membership_revoked_v1 stored in realm server
     → FACT on {realm}.membership.revoked

2. Realm server's own PM on_member_removed_rotate_key:
     observes the membership fact → dispatches rotate_realm_key_v1
       reason: :member_revoked
       urgency: :immediate

3. RealmAggregate.execute(rotate_realm_key_v1):
     - mints fresh K_realm v(N+1)
     - seals with SECRET_KEY_BASE
     - emits realm_key_rotated_v1 with {old_version, new_version, k_realm_encrypted, reason, triggered_by}
     - emitter publishes to {realm}.keys.rotated

4. Every member daemon listens to {realm}.keys.rotated:
     - unwrap new K_realm (same flow as Phase C.2 fetch)
     - seal locally, dispatch store_realm_shared_key_v1

5. On receiving realm_shared_key_stored_v1 (new version), each member's
   on_realm_key_rotated_rewrap_licenses PM fires (issuer-side only):
     - iterates my-issued-realm-scoped-active-licenses (projection lookup)
     - for each: unseal origin_cek_sealed (plaintext CEK)
                 → wrap with new K_realm
                 → dispatch rewrap_license_v1 {license_id, new_wrapped_cek, new_k_realm_version}
     - emits license_rewrapped_v1 events
     - batched emitter publishes to {realm}.licenses.rewrapped

6. Recipients listen to {realm}.licenses.rewrapped:
     - updates stored wrapped_cek + k_realm_version
     - plaintext CEK unchanged (still sealed locally from accept-time)
     - open-path continues to work uninterrupted
```

### Resignation flow (cooperative departure)

```
1. Bob hits "Leave realm" in hecate-web.
2. Bob's daemon: resign_realm_membership_v1 cmd
     → realm_membership_resigned_v1 (local, in guide_realm_memberships)
     → FACT on {realm}.membership.resigned
     → local end_realm_membership dispatched concurrently
     → realm_membership_ended_v1 {reason: :resigned} (terminal local event)
3. Realm server listens to {realm}.membership.resigned:
     - records realm_membership_resigned_v1 in realm server store
     - dispatches rotate_realm_key_v1 with urgency: :debounced_60s
4. Rotation fires after 60s (batches with any other departures in window)
5. Bob stops fetching K_realm updates after his own local end event.
```

### Revocation flow (admin ejection)

```
1. Admin (operator of realm) dispatches revoke_realm_membership_v1 on macula-realm
     (via admin UI or mix task)
     - Carries: target_did, revoked_by, reason
2. MembershipAggregate.execute on realm server
     → realm_membership_revoked_v1 stored in realm server's membership store
     → FACT on {realm}.membership.revoked
3. Carol's daemon listens to {realm}.membership.revoked:
     - matches own DID → dispatches end_realm_membership
     - realm_membership_ended_v1 {reason: :revoked, ended_by: admin_did}
     - local flag MEMBERSHIP_ENDED set; subsequent opens gated
4. Realm server rotation PM fires immediately (urgency: :immediate).
5. Rewrap cascades as above.
```

---

## Part 1 — Identity pubkey infrastructure

### Goal

Every realm member has a publishable X25519 encryption pubkey that other members can look up. Foundation for DID-scope wrapping.

### Keypair

**Derivation.** Derive the X25519 keypair deterministically from the daemon's Ed25519 signing key (reusing `hecate_identity`'s existing identity). Standard libsodium conversion: `crypto_sign_ed25519_sk_to_curve25519`, `crypto_sign_ed25519_pk_to_curve25519`. One function call at daemon init. No new keypair storage — reconstructable from the signing key at any time.

**Access:**
```erlang
-spec hecate_identity:encryption_keypair() -> {ok, {Pubkey :: binary(), Privkey :: binary()}} | {error, term()}.
```

### Publication (daemon side)

**New slice:** `apps/guide_realm_memberships/src/announce_identity_public_key/`

- Command: `announce_identity_public_key_v1 {membership_id, did, encryption_pubkey}`
- Event: `identity_public_key_announced_v1 {membership_id, did, encryption_pubkey, announced_at}`
- Handler: `maybe_announce_identity_public_key`

**Trigger:** PM `on_realm_shared_key_stored_announce_public_key` — fires once K_realm is stored (meaning we've successfully completed realm-join). Dispatches the announce command. Idempotent — re-announcement is a no-op at aggregate level (checks `IDENTITY_PUBKEY_ANNOUNCED` status bit).

**Mesh emission:** new emitter `identity_public_key_announced_v1_to_mesh` → publishes to `{realm}.identity.public_key_announced`.

### Registry (macula-realm side)

**New umbrella app:** `apps/project_realm_identities/` (PRJ). Thin — just a projection into a new `realm_identities` Ecto table.

Migration: `20260422_create_realm_identities.exs`
```sql
CREATE TABLE realm_identities (
  realm_id       TEXT NOT NULL,
  did            TEXT NOT NULL,
  encryption_pubkey BYTEA NOT NULL,
  announced_at   TIMESTAMP NOT NULL,
  updated_at     TIMESTAMP NOT NULL,
  PRIMARY KEY (realm_id, did)
);
```

**Listener:** new mesh listener (on realm server) subscribed to `{realm}.identity.public_key_announced`. Dispatches `record_member_public_key_v1` command against a new aggregate in a new `realm_identities_store`.

Wait — simpler. The realm server doesn't need an aggregate for pubkey registry; it's read-only from realm-wide authority perspective. Just a projection into Ecto. The listener writes directly to the read model via the projection pattern.

Final shape: no aggregate on realm server side for identities. Listener dispatches a projection that upserts the `realm_identities` row. If later we need audit of who changed their pubkey when, promote to event-sourced — YAGNI for now.

**Query facade:** `QueryRealmIdentities` module with `get_public_keys(realm, dids)` — batch lookup, returns map `#{did => pubkey}`.

**RPC handler:** `io.macula.realm.get_member_public_keys` on realm server, backed by `QueryRealmIdentities`. Takes `#{realm, dids: [...]}` returns `#{realm, keys: [{did, pubkey_b64}, ...]}`.

### DID crypto module (daemon side)

**New module:** `apps/shared/src/hecate_did_crypto.erl`

```erlang
-module(hecate_did_crypto).
-export([wrap_for_did/2, unwrap_from_did/2]).

%% ECIES wrap — anyone-to-recipient, ephemeral-static.
%% Output: <<EphemeralPub:32, Nonce:12, Tag:16, Ciphertext/binary>>
-spec wrap_for_did(RecipientPub :: binary(), Plaintext :: binary())
      -> {ok, binary()} | {error, term()}.

%% ECIES unwrap using recipient's own privkey.
-spec unwrap_from_did(RecipientPriv :: binary(), Sealed :: binary())
      -> {ok, binary()} | {error, term()}.
```

**Primitives:**
- X25519 ECDH: `crypto:compute_key(ecdh, PeerPub, OwnPriv, x25519)`
- HKDF with SHA-256: derive 256-bit wrap key from shared secret
- AES-256-GCM for actual envelope

**Tests:** mint keypair, wrap, unwrap, tamper detection, wrong-recipient-fails. Mirror `hecate_realm_crypto_tests.erl` shape.

### Session 1 deliverables

- `hecate_identity:encryption_keypair/0` (uses `enacl` / `libsodium` NIF for Ed25519→X25519 conversion).
- `announce_identity_public_key/` desk + `identity_public_key_announced_v1` event + emitter.
- PM `on_realm_shared_key_stored_announce_public_key` in hecate-daemon.
- `apps/project_realm_identities/` umbrella app in macula-realm with migration + listener + projection.
- `QueryRealmIdentities` facade.
- `io.macula.realm.get_member_public_keys` RPC handler (wired via `apply/3` pattern from Phase C.1).
- `hecate_did_crypto` module + eunit tests.
- End-to-end test in dev environment: daemon announces, realm server stores, second daemon queries and gets the pubkey back.

---

## Part 2 — License issuance (both scopes)

### Goal

`file_shared_v1` in briefcase triggers license issuance (one per grantee). Licenses carry wrapped CEKs appropriate to their scope.

### Changes to `guide_briefcase_lifecycle`

**Handler `maybe_share_file`** is extended:
- Determine recipients from `share_file_v1` payload (`recipients: :realm | [DID]`).
- Mint CEK: `crypto:strong_rand_bytes(32)`.
- For each recipient:
  - If recipient is `:realm`: `hecate_realm_crypto:wrap(realm, CEK)` → `wrapped_cek`, `wrap_strategy = :realm_key_v1`, `grantee = <<"mri:realm:", Realm/binary>>`.
  - If recipient is a DID: lookup pubkey via `QueryRealmIdentities:get_public_keys/2` → `hecate_did_crypto:wrap_for_did/2` → `wrapped_cek`, `wrap_strategy = :did_x25519_v1`, `grantee = DID`.
- Dispatches one `issue_license_v1` per (file_id, grantee).
- Also stores `origin_cek_sealed = hecate_crypto:encrypt(CEK)` per license — for future rewrap.

### Changes to `guide_license_lifecycle`

**New slice:** `apps/guide_license_lifecycle/src/issue_license/`

- Command: `issue_license_v1 {license_id, grantee, file_id, wrap_strategy, wrapped_cek, origin_cek_sealed, k_realm_version, issued_at, expires_at}`
- Event: `license_issued_v1 {...same fields, plus issuer_did}`
- Handler: `maybe_issue_license` — validates scope, dispatches.
- Aggregate: extend `license_aggregate` with `issue_license_v1` command handling and corresponding event-apply in `license_state`.

**State additions:**
```erlang
-record(license_state, {
  % existing fields...
  grantee                :: binary() | undefined,  % "mri:realm:..." or "did:macula:..."
  file_id                :: binary() | undefined,
  wrap_strategy          :: atom() | undefined,    % :realm_key_v1 | :did_x25519_v1
  wrapped_cek            :: binary() | undefined,
  origin_cek_sealed      :: binary() | undefined,  % issuer-only; recipients have accepted_cek_sealed instead
  accepted_cek_sealed    :: binary() | undefined,  % recipient-only (from accept_license_v1)
  k_realm_version        :: non_neg_integer() | undefined,  % for realm-scope only
  issuer_did             :: binary() | undefined,
  issued_at              :: integer() | undefined,
  accepted_at            :: integer() | undefined,
  revoked_at             :: integer() | undefined,
  rewrapped_at           :: integer() | undefined,
  expires_at             :: integer() | undefined,
  status                 :: non_neg_integer()  % bit flags
}).
```

**Status flags** (`license_status.hrl`):
```erlang
-define(LICENSE_ISSUED,     1).
-define(LICENSE_ACCEPTED,   2).
-define(LICENSE_REVOKED,    4).
-define(CEK_USABLE,         8).   % set on accept, cleared on revoke
-define(LICENSE_REWRAPPED, 16).   % audit-level; multiple rewraps just re-set
```

### Batched mesh emission

**New slice:** `apps/guide_license_lifecycle/src/license_issued_v1_to_mesh/`

Not a per-event emitter. Instead, batches licenses for the same share into a single mesh publish.

**Implementation:**
- `file_shared_v1` carries a `batch_id` field (generated by `maybe_share_file`).
- When `issue_license_v1` commands are dispatched, they all carry the same `batch_id`.
- A new emitter `licenses_issued_batch_emitter` — gen_server that subscribes to `license_issued_v1` events. Buffers events by `batch_id`, flushes after 500ms of quiescence (or N events, whichever first).
- Flush: constructs `licenses_issued_batch_v1` FACT containing `[{license_id, grantee, wrap_strategy, wrapped_cek, expires_at}, ...]` for the batch, publishes once to `{realm}.licenses.issued_batch`.

**Why in the emitter, not the aggregate:** batching is transport-optimization, not domain logic. Aggregate stays one-license-per-command; emitter collapses to one mesh event.

**Trade-off accepted:** 500ms delay between issue and mesh publish. Acceptable for Phase D (license delivery is eventually-consistent anyway via catch-up).

### Session 2 deliverables (Part 2 slice)

- `issue_license_v1` command + event + handler + aggregate routing.
- License state extensions + status flags.
- Extensions to `maybe_share_file` for CEK mint + per-recipient wrap + `origin_cek_sealed`.
- `licenses_issued_batch_emitter` gen_server + supervision wiring.
- End-to-end test (pure unit): aggregate walking skeleton, with/without realm-scope, with/without DID-scope.

---

## Part 3 — Realm server license registry + replay

### Goal

Realm server observes all `{realm}.licenses.*` topics, persists events to a dedicated store, and exposes replay RPC so reconnecting daemons can catch up on missed license events.

### New umbrella app: `apps/guide_license_registry/`

Note: PRJ/QRY-less app, just listeners + event store. The raw log IS the read model for replay purposes.

**Structure:**
```
apps/guide_license_registry/
├── lib/guide_license_registry/
│   ├── application.ex
│   ├── listen_for_license_issued_batch/
│   ├── listen_for_license_revoked/
│   ├── listen_for_license_rewrapped/
│   ├── replay_events_rpc.ex
│   └── registry_store.ex          # evoq store wiring
└── mix.exs
```

**Listeners:** one per topic. Each subscribes via `macula:subscribe` to its topic. On receipt, appends a typed event to `{realm}_licenses_store` (new reckon_db store). No aggregate — events are raw-logged.

Wait — reckon_db wants a stream per event sequence. We need a single append-only stream for all license events in a realm. Options:

- **Single stream `licenses-{realm_id}`** — all license events (issued/revoked/rewrapped) appended in order. Replay is a range read.
- **Stream per event type** — harder to replay in order; rejected.

Going with single stream. Stream convention: `<<"licenses-", RealmId/binary>>` — same pattern as briefcase uses `briefcase-{file_id}`.

**Replay RPC handler** `replay_events_rpc.ex`:
```elixir
defmodule GuideLicenseRegistry.ReplayEventsRpc do
  def advertise(client) do
    :macula.advertise(client, "io.macula.licenses.replay_events_v1", &handle/1)
  end

  def handle(%{"realm" => realm, "since" => since} = args) do
    limit = Map.get(args, "limit", 500)
    event_types = Map.get(args, "event_types", :all)
    # reads {realm}_licenses_store stream from `since` offset
    # returns {:ok, %{events: [...], next_since: N}}
  end
end
```

Pattern matches `mesh_catch_up:advertise_replay/3` conceptually (same shape: offset + limit + typed events). Could reuse the `mesh_catch_up` producer API:
```elixir
mesh_catch_up:advertise_replay("io.macula", :licenses_store, <<"licenses">>)
```

But `mesh_catch_up` is generic — it expects the store to be local to the advertising process. Since realm server owns the licenses store, it can advertise directly. Reuse fine.

### Session 2 deliverables (Part 3 slice)

- `apps/guide_license_registry/` umbrella app.
- Three listeners (issued_batch, revoked, rewrapped) appending to `{realm}_licenses_store`.
- Replay RPC handler advertised as `io.macula.licenses.replay_events_v1`.
- End-to-end test with two mock daemons: daemon A publishes a license batch, realm server persists it, daemon B calls replay and receives the events.

---

## Part 4 — Accept + catch-up

### Goal

Receiving daemon sees incoming license events (live from mesh or via catch-up), unwraps CEK, stores sealed plaintext CEK locally, marks license as accepted.

### Accept slice

**New slice:** `apps/guide_license_lifecycle/src/accept_license/`

- Command: `accept_license_v1 {license_id, file_id, grantee, wrap_strategy, wrapped_cek, k_realm_version, issuer_did, issued_at, expires_at}`
- Event: `license_accepted_v1 {license_id, accepted_cek_sealed, accepted_at}`
- Handler: `maybe_accept_license`
  - Decides wrap_strategy:
    - `:realm_key_v1` → `hecate_realm_crypto:unwrap(realm, wrapped_cek)` → plaintext CEK
    - `:did_x25519_v1` → `hecate_did_crypto:unwrap_from_did(own_privkey, wrapped_cek)` → plaintext CEK
  - Seals plaintext: `hecate_crypto:encrypt(plaintext_cek)` → `accepted_cek_sealed`
  - Emits `license_accepted_v1`. NOTE: this event carries the ORIGINAL `license_id`, `file_id`, etc. so the aggregate state is fully reconstructable on replay. Recipient's aggregate state also has `grantee`, `wrap_strategy`, `k_realm_version` copied from the issued event (needed for later rewrap application).

**Aggregate state update:** on `license_accepted_v1`, set `accepted_cek_sealed`, `accepted_at`, flip `LICENSE_ACCEPTED | CEK_USABLE` bits.

Actually — rethinking the aggregate boundary. Two options:

**Option A:** The ISSUER's license aggregate and the RECIPIENT's license aggregate are the SAME aggregate ID (both stream `license-{license_id}`). Issuer emits `issued`, recipient receives via mesh and emits `accepted` against the same aggregate stream.

Problem: the stream lives on ONE daemon. Two daemons can't append to the same stream. Events emitted by Alice are in Alice's store; events emitted by Bob are in Bob's store.

**Option B:** Two distinct aggregates — `issued_license_{license_id}` on issuer side, `accepted_license_{license_id}` on recipient side. Each owns its own event stream.

Option B is the clean event-sourced answer. Each daemon owns its own view of the license.

Event vocabulary then needs two flavors:
- On the issuer: `license_issued_v1`, `license_revoked_v1`, `license_rewrapped_v1` (all local to issuer's store).
- On the recipient: `license_accepted_v1`, `license_ended_v1` (when revoked received from mesh), `license_rewrap_received_v1`.

Events on the mesh (issued_batch, revoked, rewrapped) carry the issuer's authoritative data. Recipient's local events are downstream reflections.

Naming the aggregates to avoid confusion:
- `issued_license_aggregate` (issuer side)
- `accepted_license_aggregate` (recipient side)

Hmm, but they share a lot of fields. Is it one aggregate module with different routing, or two distinct modules?

**Proposal: two distinct aggregates.** Each has its own state, commands, events. Explicit Over Clever. A license-I-issued and a license-I-accepted are semantically different things from my daemon's perspective.

Stream IDs:
- `issued-license-{license_id}` for issuer side
- `accepted-license-{license_id}` for recipient side

(Or reuse `license_id` as aggregate_id with a type prefix in stream naming. Implementation detail.)

### Catch-up worker (daemon side)

**New slice:** `apps/guide_license_lifecycle/src/catch_up_realm_licenses/`

Gen_server under `guide_license_lifecycle_sup`. Similar shape to `catch_up_realm_keys`:

- Polls `hecate_mesh:is_activated/0` (with `whereis` guard per feedback_cross_app_gen_server_race.md).
- On activation: for each joined realm (iterate `project_realm_memberships_store:list_confirmed/0`):
  - Get last position via `mesh_catch_up:get_position(<<"licenses-", RealmId/binary>>)`.
  - Call `io.macula.licenses.replay_events_v1` with `since: Position`.
  - For each returned event, dispatch the appropriate local command (`accept_license_v1` / `end_license_v1` / receive-rewrap).
  - Save position after each batch.
  - Update `last_license_catchup` timestamp per realm.
- Repeats every 2-3 minutes (tighter than K_realm catch-up because security-critical).

**Idempotency:** recipient's aggregate guards against re-accepting — status bit check + monotonic offset check.

### Listener for live events

**New slice:** `apps/guide_license_lifecycle/src/listen_for_license_batch/`

Dispatches commands in real-time when the mesh pub/sub delivers events. Complements catch-up; when daemon is online, events arrive live and don't need replay.

### Session 2 deliverables (Part 4 slice)

- `accept_license/` desk + command + event + handler.
- `accepted_license_aggregate` module + state module.
- `catch_up_realm_licenses/` gen_server with whereis guard.
- `listen_for_license_batch/` mesh listener.
- End-to-end test: daemon A publishes batch, realm server persists, daemon B online receives live, daemon C offline reconnects and catches up via replay.

---

## Part 5 — Revocation + end_realm_membership

### Revoke license

**Existing slice extended:** `apps/guide_license_lifecycle/src/revoke_license/`

- Command `revoke_license_v1` stays. Handler emits `license_revoked_v1`.
- State change: clear `CEK_USABLE` bit, set `LICENSE_REVOKED`, record `revoked_at` + `reason`.
- Emitter publishes `{realm}.licenses.revoked` (single event, NOT batched — revocations are per-license and we want them delivered promptly).
- Recipient listener `listen_for_license_revoked`: dispatches `end_license_v1` on recipient's side. Recipient's aggregate clears `CEK_USABLE`, stores `revoked_at`.

### End membership (terminal daemon-side)

**Rename existing slice:** `apps/guide_realm_memberships/src/revoke_realm_membership/` → `end_realm_membership/`.

Per D8 decision:
- Command: `end_realm_membership_v1 {membership_id, reason, ended_by, ended_at}`
- Event: `realm_membership_ended_v1 {same fields}`
- Handler: `maybe_end_realm_membership`
- Event upcaster in `membership_state`: old `realm_membership_revoked_v1` events in the stream upcast to `realm_membership_ended_v1 {reason: :revoked}` on replay. Keeps history readable after rename.

**Entry points:**
- Self-resignation: user clicks "Leave realm" → web hits `POST /api/realms/{id}/resign` → dispatches `resign_realm_membership_v1` command (new), which emits `realm_membership_resigned_v1` (local), AND emits a concurrent `end_realm_membership_v1` with `reason: :resigned`. Two events, two flags (`MEMBERSHIP_RESIGNED | MEMBERSHIP_ENDED`).
- Listener-dispatched: `listen_for_membership_revoked` subscribes to `{realm}.membership.revoked`. On receipt matching own DID, dispatches `end_realm_membership_v1 {reason: :revoked, ended_by: admin_did}`.

**New slices:**
- `apps/guide_realm_memberships/src/resign_realm_membership/` — member-initiated resignation.
- `apps/guide_realm_memberships/src/end_realm_membership/` — terminal state transition (both resign and revoke path lead here).
- `apps/guide_realm_memberships/src/listen_for_membership_revoked/` — mesh listener subscribing to `{realm}.membership.revoked`.

### Realm server side

**Extend macula-realm:**
- `guide_realm_lifecycle` aggregate gains `revoke_realm_membership_v1` command (admin authority — gated by operator DID allowlist or mix task).
- Emits `realm_membership_revoked_v1` — admin-authoritative event.
- Emitter publishes to `{realm}.membership.revoked`.

- `guide_realm_lifecycle` aggregate also adds `record_realm_membership_resigned_v1` command, triggered by a new listener on `{realm}.membership.resigned`. Persists the resignation event in realm server store (for audit).

### Rotation triggers

Both on the realm server:
- `on_realm_membership_revoked_rotate_key` PM — fires on `realm_membership_revoked_v1` stored in realm server, dispatches `rotate_realm_key_v1 {reason: :member_revoked, urgency: :immediate}`.
- `on_realm_membership_resigned_rotate_key` PM — fires on `realm_membership_resigned_v1` stored in realm server, dispatches `rotate_realm_key_v1 {reason: :member_resigned, urgency: :debounced_60s}`.

### Debounce inside RealmAggregate

`rotate_realm_key_v1 {urgency: :debounced_60s}` doesn't rotate immediately. Aggregate stores pending rotation in state, sets `DEBOUNCED_ROTATION_PENDING` flag, schedules an internal timer.

If another debounced rotate arrives within the window: merge (same target window).
If an immediate rotate arrives: cancel timer, fire immediately.
On timer fire: emit `realm_key_rotated_v1`, clear flag.

### Session 2/3 deliverables (Part 5 slice)

- Extensions to `revoke_license/`: recipient listener, end_license dispatch.
- Rename `revoke_realm_membership` → `end_realm_membership` with upcaster.
- New `resign_realm_membership/`, `listen_for_membership_revoked/` on daemon side.
- New `revoke_realm_membership` on realm server side (admin authority).
- New listeners + PMs on realm server for rotation triggering.
- Debounce state machine in `RealmAggregate`.
- Tests: full revoke flow (Carol kicked → rotation fires → Alice rewraps → Bob receives rewrap), full resign flow (Dave leaves → rotation debounces → fires after 60s).

---

## Part 6 — Rewrap-on-rotation

### Goal

When `K_realm` rotates, every realm-scope license issued by each daemon gets re-wrapped under the new key. Recipients' accepted plaintext CEKs are unchanged (eager unwrap already happened); only their stored `wrapped_cek` metadata gets updated.

### Issuer-side PM

**New slice:** `apps/guide_license_lifecycle/src/on_realm_key_rotated_rewrap_licenses/`

Triggered by: local `realm_shared_key_stored_v1` event (not mesh directly — we use our own stored event as the signal that we have the new key available). This ensures we don't start rewrapping until our local `hecate_realm_crypto:wrap/2` can actually use the new K_realm.

**Logic:**
```
handle_event(_, Event, _, State):
  NewVersion = event.k_realm_version
  Realm = event.realm
  OldVersion = NewVersion - 1
  
  % list all my issued, active, realm-scoped licenses with old version
  Licenses = query_issued_licenses({
    issuer: self_did(),
    status_match: LICENSE_ISSUED + LICENSE_ACCEPTED - LICENSE_REVOKED,
    wrap_strategy: :realm_key_v1,
    k_realm_version: OldVersion,
    realm: Realm
  })
  
  % batch them — single mesh publish
  BatchId = uuid()
  for License in Licenses:
    {ok, PlaintextCEK} = hecate_crypto:decrypt(License.origin_cek_sealed)
    {ok, NewWrappedCEK} = hecate_realm_crypto:wrap(Realm, PlaintextCEK)
    dispatch(rewrap_license_v1{
      license_id: License.license_id,
      new_wrapped_cek: NewWrappedCEK,
      new_k_realm_version: NewVersion,
      batch_id: BatchId
    })
  
  % emitter flushes batch via {realm}.licenses.rewrapped_batch
```

### New slice on issuer side

**New slice:** `apps/guide_license_lifecycle/src/rewrap_license/`

- Command: `rewrap_license_v1 {license_id, new_wrapped_cek, new_k_realm_version, batch_id}`
- Event: `license_rewrapped_v1 {same fields, rewrapped_at}`
- Handler: `maybe_rewrap_license`
- Aggregate guard: reject if `new_k_realm_version <= current_k_realm_version` (monotonic, idempotent on replay).

### Batched mesh emission

Same pattern as Part 2. Buffered emitter, one `licenses_rewrapped_batch_v1` FACT per rotation event for a given issuer.

### Recipient side

**New slice:** `apps/guide_license_lifecycle/src/listen_for_license_rewrapped/`

Listens to `{realm}.licenses.rewrapped_batch`. For each entry matching a license this daemon has accepted:
- Dispatch `receive_license_rewrap_v1` command against `accepted_license_aggregate`.
- Event `license_rewrap_received_v1` updates `wrapped_cek` + `k_realm_version` on the aggregate (audit-only — `accepted_cek_sealed` plaintext is unchanged).

### Query projection for issuer's licenses

**New read model:** `my_issued_realm_scoped_active_licenses`. ETS table keyed by `{realm, k_realm_version}`, values are lists of `license_id`. Maintained by a projection subscribing to `license_issued_v1` / `license_revoked_v1` / `license_rewrapped_v1`.

On rotation, the PM queries `my_issued_realm_scoped_active_licenses[{realm, old_version}]` — O(1) lookup — gets all license_ids needing rewrap, iterates.

### Snapshot-friendliness

Phase D doesn't implement aggregate snapshots. But the design is snapshot-compatible:
- Each `rewrap_license_v1` event bumps the aggregate's `k_realm_version` field.
- A snapshot at any point captures current version + sealed CEK.
- Replay from a snapshot + events after gives the same end state.

When rewrap time becomes painful (say, issuer has 10k realm-scope licenses and K_realm rotates weekly): add snapshotting to `issued_license_aggregate` via `evoq_aggregate`'s optional `snapshot/1` + `from_snapshot/1` callbacks. Phase D+.

### Session 3 deliverables

- `rewrap_license/` desk + command + event + handler.
- `on_realm_key_rotated_rewrap_licenses` PM on issuer side.
- Batched emitter for rewrap events.
- Recipient `listen_for_license_rewrapped` slice.
- Projection for issuer's realm-scope license tracking.
- Test: realm has 3 daemons (Alice issues to realm), Bob + Carol accept, Dave is revoked → rotation fires → Alice rewraps 5 active licenses → Bob + Carol receive updates → their `open` continues to work → Dave cannot unwrap (CEK_UNUSABLE via revoke listener anyway).

---

## Part 7 — Staleness guard

### Goal

Open-path in Phase F refuses licenses whose state isn't fresh enough, preventing decryption based on stale authorization data.

### Design

A single per-realm timestamp: `last_license_catchup_at`, updated by `catch_up_realm_licenses` after each successful sweep. Stored in `realm_shared_keys` ETS entry (reuse existing table, add field).

On open-path (Phase F):
```erlang
can_open(License, Realm) ->
  Now = system_time(millisecond),
  StaleThreshold = application:get_env(hecate, license_staleness_threshold_ms, 86400000),  % 24h
  LastCatchup = last_license_catchup(Realm),
  case Now - LastCatchup < StaleThreshold andalso
       License.expires_at > Now andalso
       has_flag(License.status, ?CEK_USABLE) of
    true  -> ok;
    false -> {error, license_state_stale_or_invalid}
  end.
```

Threshold configurable. Default 24 hours — lets offline use up to a day, then forces online-confirmation. Tightens to 1 hour for high-security realms (operator config).

### Session 4 deliverable

- Extend `hecate_realm_crypto` or add `hecate_license_guard` with `can_open/2`.
- Record `last_license_catchup_at` in `realm_shared_keys` ETS.
- Wire into Phase F when that lands. For Phase D, just expose the function; Phase F is the consumer.

---

## Event vocabulary summary

### hecate-daemon — guide_realm_memberships

New:
- `announce_identity_public_key_v1` / `identity_public_key_announced_v1`
- `resign_realm_membership_v1` / `realm_membership_resigned_v1` (mesh-published)
- `end_realm_membership_v1` / `realm_membership_ended_v1` (terminal local state)

Renamed (with upcaster):
- `revoke_realm_membership_v1` → `end_realm_membership_v1 {reason: :revoked}`
- `realm_membership_revoked_v1` (daemon-local) → `realm_membership_ended_v1 {reason: :revoked}` on replay

Reserved for future:
- `amend_realm_membership_v1` / `realm_membership_amended_v1` (suspensions, role changes)

### hecate-daemon — guide_license_lifecycle

New commands/events:
- `issue_license_v1` / `license_issued_v1` (issuer-local + batch-published)
- `accept_license_v1` / `license_accepted_v1` (recipient-local only)
- `end_license_v1` / `license_ended_v1` (recipient-local, when revoke fact received)
- `rewrap_license_v1` / `license_rewrapped_v1` (issuer-local + batch-published)
- `receive_license_rewrap_v1` / `license_rewrap_received_v1` (recipient-local)

Existing (unchanged):
- `revoke_license_v1` / `license_revoked_v1` (mesh-published)

### macula-realm — guide_realm_lifecycle

New:
- `revoke_realm_membership_v1` / `realm_membership_revoked_v1` (admin authority)
- `record_realm_membership_resigned_v1` / `realm_membership_resigned_v1` (from mesh)
- `rotate_realm_key_v1` extended with `reason` + `urgency` + `triggered_by`

### Mesh topics (all via `hecate_topics:fact/3`)

```
{realm}.identity.public_key_announced
{realm}.membership.revoked
{realm}.membership.resigned
{realm}.keys.rotated
{realm}.licenses.issued_batch
{realm}.licenses.revoked
{realm}.licenses.rewrapped_batch
```

### Mesh RPCs (via `hecate_topics:hope/3`)

```
io.macula.realm.get_member_public_keys
io.macula.licenses.replay_events_v1
```

---

## File layout

### hecate-daemon

```
apps/shared/src/
├── hecate_did_crypto.erl                             [new]
└── (existing hecate_realm_crypto.erl, hecate_crypto.erl unchanged)

apps/guide_realm_memberships/src/
├── announce_identity_public_key/                     [new]
├── end_realm_membership/                             [renamed from revoke_realm_membership]
├── resign_realm_membership/                          [new]
├── listen_for_membership_revoked/                    [new]
├── on_realm_shared_key_stored_announce_public_key/   [new PM]
└── (existing initiate, confirm, secure_realm_credentials, store_realm_shared_key, catch_up_realm_keys)

apps/guide_license_lifecycle/src/
├── issue_license/                                    [new]
├── accept_license/                                   [new]
├── end_license/                                      [new]
├── rewrap_license/                                   [new]
├── receive_license_rewrap/                           [new]
├── listen_for_license_batch/                         [new]
├── listen_for_license_revoked/                       [new]
├── listen_for_license_rewrapped/                     [new]
├── catch_up_realm_licenses/                          [new]
├── on_realm_key_rotated_rewrap_licenses/             [new PM]
├── licenses_issued_batch_emitter.erl                 [new]
├── licenses_rewrapped_batch_emitter.erl              [new]
├── issued_license_aggregate.erl                      [new]
├── issued_license_state.erl                          [new]
├── accepted_license_aggregate.erl                    [new]
├── accepted_license_state.erl                        [new]
└── (existing license_aggregate — keep or deprecate?)

apps/project_licenses/src/
├── (new projection for my_issued_realm_scoped_active_licenses)

apps/query_licenses/src/
├── (extend with get_my_issued / get_my_accepted lookups)
```

### macula-realm

```
system/apps/
├── guide_realm_lifecycle/                            [existing, extend]
│   └── lib/.../rotate_realm_key/
│       (extend with reason + urgency + debounce state machine)
│   └── lib/.../revoke_realm_membership/              [new]
│   └── lib/.../record_realm_membership_resigned/     [new]
│   └── lib/.../on_realm_membership_revoked_rotate_key/   [new PM]
│   └── lib/.../on_realm_membership_resigned_rotate_key/  [new PM]
│
├── guide_license_registry/                           [new app]
│   └── lib/.../listen_for_license_issued_batch/
│   └── lib/.../listen_for_license_revoked/
│   └── lib/.../listen_for_license_rewrapped/
│   └── lib/.../replay_events_rpc.ex
│   └── lib/.../registry_store.ex
│
├── project_realm_identities/                         [new app]
│   └── lib/.../identities_listener.ex
│   └── lib/.../identities_projection.ex
│
├── query_realm_identities/                           [new app]
│   └── lib/.../query_realm_identities.ex
│
├── project_realm/                                    [existing, no change]
├── query_realm/                                      [existing, no change]
│
└── macula_realm/
    └── priv/repo/migrations/
        └── 20260422_create_realm_identities.exs      [new]

└── config/runtime.exs                                [add license_staleness_threshold_ms]
```

---

## Implementation sequence (sessions)

### Session 1 — Identity pubkey infrastructure

**hecate-daemon:**
- `hecate_did_crypto` module + tests.
- Ed25519 → X25519 conversion in `hecate_identity`.
- `announce_identity_public_key/` desk.
- `on_realm_shared_key_stored_announce_public_key` PM.
- Emitter for the announcement.

**macula-realm:**
- Migration for `realm_identities` table.
- `project_realm_identities` app (listener + projection).
- `query_realm_identities` app.
- `io.macula.realm.get_member_public_keys` RPC handler.

**Test:** 2-daemon roundtrip. Daemon A announces pubkey → realm server records → daemon B queries and gets back.

### Session 2 — License issuance + accept + live delivery

**hecate-daemon:**
- Extend `maybe_share_file` with CEK mint + per-recipient wrap.
- `issue_license/`, `accept_license/`, `end_license/` desks.
- `issued_license_aggregate` + `accepted_license_aggregate`.
- `licenses_issued_batch_emitter` (buffered).
- `listen_for_license_batch` + `listen_for_license_revoked` listeners.
- `revoke_license` recipient-side wiring.

**macula-realm:**
- `guide_license_registry` app with three listeners + store.
- `io.macula.licenses.replay_events_v1` RPC handler.

**Test:** 2-daemon live path. Alice shares with Bob (DID-scope), Bob receives live, opens via catch-up test path.

### Session 3 — Catch-up + revocation + membership reshape

**hecate-daemon:**
- `catch_up_realm_licenses/` gen_server with whereis guard.
- Rename `revoke_realm_membership` → `end_realm_membership` with upcaster.
- `resign_realm_membership/`, `listen_for_membership_revoked/` desks.

**macula-realm:**
- Admin `revoke_realm_membership` slice (realm-server-side).
- `record_realm_membership_resigned` slice.
- Two rotation PMs (revoke + resign).
- Extend `rotate_realm_key` aggregate with reason + urgency + debounce state.

**Test:** 3-daemon scenario. Alice issues to realm, Bob online receives live, Carol offline → reconnects → catches up → has both licenses. Dave is revoked → rotation fires immediately → Alice rewraps → Bob + Carol get rewrap events.

### Session 4 — Rewrap-on-rotation + staleness + test hardening

**hecate-daemon:**
- `rewrap_license/`, `receive_license_rewrap/` desks.
- `on_realm_key_rotated_rewrap_licenses` PM.
- `listen_for_license_rewrapped` slice.
- `licenses_rewrapped_batch_emitter`.
- `my_issued_realm_scoped_active_licenses` projection.
- Staleness guard (`hecate_license_guard:can_open/2`).

**macula-realm:**
- Rewrap batch listener (extends `guide_license_registry`).

**Test:** resign flow with debounce. 3 daemons resign within 60s → single rotation fires → all rewraps happen → staleness guard on fake-clock test refuses opens after 24h offline.

---

## Testing strategy

### Unit (eunit + ExUnit)

- `hecate_did_crypto`: wrap/unwrap roundtrip, tamper detect, wrong recipient fails.
- Aggregate tests: issued + accepted + end + rewrap lifecycle per state machine.
- Projection tests: `my_issued_realm_scoped_active_licenses` correctness.
- Batch emitter: buffers N events, flushes on quiescence, flushes on limit.
- Debounce state machine: multiple debounced rotations coalesce; immediate overrides.

### Integration (Common Test)

- 2-daemon identity + license issuance (Session 1 + 2 deliverables).
- 3-daemon catch-up scenario with offline daemon (Session 3).
- Rotation flow with rewrap cascade (Session 3 + 4).
- Staleness guard with simulated clock skew (Session 4).

### Live dev environment

- 2-daemon test on `host00.lab` against macula.io (using existing dev Postgres + realm server).
- Later, 4-daemon test on beam cluster.

### Security tests

- Tamper with wrapped_cek → accept fails cleanly.
- Replay old (pre-rotation) wrapped_cek → guard rejects (k_realm_version mismatch).
- Revoked license replay → accept rejected due to LICENSE_REVOKED flag.

---

## Open questions / decisions deferred

- **Realm-scope license naming.** When Alice shares "to realm," is the license carried by a single logical license_id (one license granting to all realm members) or multiple (one per member)? Recommend single — realm is a collective grantee. A single `license_issued_v1` with `grantee = "mri:realm:io.macula"` and `wrap_strategy = :realm_key_v1`. Each realm member's recipient-side `accepted_license_aggregate` stores their local view. Keeps the crypto + event count low.

- **Admin authority mechanism.** `revoke_realm_membership_v1` on realm server requires operator authority. Options: (1) mix task (operator SSH access = authority), (2) new admin API behind Hanko auth. Phase D: mix task. Admin API in a later operator-tooling plan.

- **Resignation undo window.** If the UI offers "undo resign within 7 days", aggregate needs to support un-ending. Currently modeled as terminal. If needed, add `restore_membership_v1` command — new membership aggregate, inherits some fields. Punt for now.

- **License size on the mesh.** A batch event with 100 entries = ~20KB. Relays likely have a per-event size limit. If we hit it, split into multiple batches of 50. Measure in Session 2.

- **Rewrap idempotency on replay.** On a daemon replaying its own stream from zero, `rewrap_license_v1` events for already-rewrapped-version will replay. Aggregate's monotonic version guard handles it, but double-check no side-effects fire (e.g., rewrap-emitter must not re-publish to mesh on replay).

---

## Success criteria (all phases)

- [ ] Alice can share a file with the realm OR with a specific subset of members; each recipient gets exactly one license.
- [ ] Batched license events: single share = single mesh publish regardless of recipient count.
- [ ] Bob receives live when online; Carol catches up when she reconnects; both end up with accepted licenses.
- [ ] Dave's revoked license fails his `open` with `{error, license_revoked}`.
- [ ] K_realm rotation triggered by any member departure (revoked or resigned).
- [ ] Rewrap cascade on rotation: all realm-scoped licenses re-wrapped; recipient plaintext CEKs unchanged.
- [ ] Rotation event carries `reason` + `triggered_by` for audit.
- [ ] Open-path refuses licenses when catch-up is stale (> 24h).
- [ ] Storage: `origin_cek_sealed` on issuer side, `accepted_cek_sealed` on recipient side, wrapped_cek in events for audit.
- [ ] No plaintext CEK or K_realm ever touches disk unsealed.
- [ ] Identity pubkey registry populated for all confirmed members.
- [ ] `hecate_did_crypto` sealed against tampering + wrong-recipient + curve substitution.

---

## Cross-references

- `PLAN_BRIEFCASE_PRESENCE_PRIVACY.md` — presence/privacy parent plan; this doc resolves its Phase D unknowns.
- `PLAN_BRIEFCASE.md` — original briefcase trinity architecture.
- `PLAN_MACULA_STREAMING.md` — Phase E content streaming depends on Phase D licenses.
- `feedback_cross_app_gen_server_race.md` — memory: whereis guards on cross-app gen_server calls.
- `feedback_viewstate_pattern.md` — daemon owns share-UI viewstate.
- Phase C.2 session log: `~/.claude/my-sessions/2026-04-21_phase-c-deploy.md`.

---

## Non-goals

- Phase E content transfer (ciphertext streaming, cache management, eviction).
- Phase F decrypt-on-use serving to hecate-web.
- Cross-realm licenses.
- DRM / forward secrecy beyond K_realm rotation.
- Federated operator model (realm server is single-authority in Phase D).
- Real-time group-key updates (no MLS-style continuous key evolution; discrete rotation only).
