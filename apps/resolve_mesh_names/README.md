# resolve_mesh_names

Tier-1 mesh-native naming service. Exposes resolve / watch / describe / verify_trust_chain / backlinks over MRIs and signed records. Push-invalidated cache. Consumed by every Tier-2 wire bridge (`serve_dns_over_mesh`, future `serve_https_over_mesh` / `serve_mdns_over_mesh`, the daemon REST API, the TUI naming browser).

**Status:** Phase 1 complete — the lookup pipeline, the 5-link trust chain, the 5-layer push-invalidated cache, the two cache-invalidation PMs, and watch subscriptions are all implemented; 83/83 CT green; and the whole path is verified live against the Macula mesh by `hecate-daemon/harness/run-live-dns-harness.sh` (`macula:put_record` → `find_record` round-trip → `resolve_mesh_names_api:resolve` with self-rooted station trust verification → L4/L5 cache → the two PMs subscribed to the live pool: all PASS). Plan: [PLAN_RESOLVE_MESH_NAMES_PART1](https://codeberg.org/macula-internal/macula-architecture/src/branch/main/plans/PLAN_RESOLVE_MESH_NAMES_PART1.md).

What works today:

- `resolve/2,3` + `refresh/2,3` — `mri:station:<z32>` resolves via the **self-rooted** path (fetch `station_endpoint` by `sha256("station_endpoint" ‖ pubkey)`, verify the self-signed signature against the pubkey in the MRI — no realm trust chain); `mri:proc:...` resolves via the full realm trust chain (leaf type `procedure_advertisement`). Both write the L4 leaf + L5 composite cache entries.
- `verify_trust_chain/3,5` — the fold-over-steps state machine: anchor → FRTL → realm_directory → **leaf → endorsement** (bottom-up — the SDK's RME storage key needs the member pubkey, which is the leaf record's `key`) → `[host_delegation]` → finalise. Real Ed25519 via `macula_record:verify/1`; errors map to the typed atoms in PLAN PART1 §6.
- `watch/3` + `unwatch/1` — subscription registry (ETS keyed by `reference()`), monitor-based auto-unwatch, current-value-on-subscribe (app env `watch_delivers_current_value`); `watch_mri:realm_changed/2` re-resolves and delivers `record_changed` / `record_tombstoned` / `trust_chain_lost`. (Station MRIs aren't matched by `realm_changed` — self-rooted, no realm to key on; station watchers get current-value-on-subscribe only — see "Known gaps".)
- `describe/2,3` — composite bundle: `records` (from `resolve`) + `endorsements` (currently `[]` — see "Known gaps") + `backlinks` (from `backlinks/2`, which currently errors — see "Known gaps") + `consensus` (`#{replicas => 1, agreed => 1}` for now) + `last_modified` + a `partial` flag.
- The two cache-invalidation PMs (`on_record_observed_invalidate_cache`, `on_realm_directory_changed_warm_cache`) — **self-bootstrap**: on start they poll `hecate_mesh:get_client/0` every `mesh_subscribe_retry_ms` (default 5 s) until the daemon's V2 pool is up, then `macula:subscribe_records/3` to their watched record types on it; they `monitor` the pool and re-bootstrap against whatever pool a mesh reactivation rebuilds. Push invalidation is realm-grain (coarse but correct); `cache_ttl_sweep` (30 s) is the safety net for missed pushes. `subscribe/1` remains as an explicit-override entry point.

## Why

Naming on the mesh has primitives DNS does not have: push notifications instead of TTL polling, signed records with first-class tombstones, composite/streaming/backlinks queries, multi-replica consensus, self-rooted identifiers, time-travel resolution. This slice exposes those mesh-native primitives idiomatically. Wire bridges (DNS, HTTPS, mDNS, REST, TUI) consume the API and translate to their own protocol shape — degrading what they must but never contaminating the naming service.

The original `serve_dns_over_mesh` plan had naming + DNS bridge fused into one slice. That fusion forced DNS shape (RRsets, TTLs, rcodes) into every consumer including HTTPS-over-mesh which has no DNS interest. The 2026-05-11 split fixed that leak at the architecture level (see `PLAN_RESOLVE_MESH_NAMES_ROOT.md` / the `PLAN_DNS_OVER_MESH_ROOT.md` decisions log).

## Layout

```
resolve_mesh_names/
├── README.md                                   ← this file
├── docs/
│   ├── API_CONTRACT.md                         ← public library_api in detail
│   ├── TRUST_CHAIN.md                          ← 5-link state machine
│   ├── PUSH_CACHE.md                           ← invalidation model
│   └── COMPOSITE_QUERIES.md                    ← describe + backlinks
├── src/
│   ├── resolve_mesh_names.app.src
│   ├── resolve_mesh_names_app.erl              ← OTP application
│   ├── resolve_mesh_names_sup.erl              ← slice-root supervisor (desk sups only)
│   ├── library_api/resolve_mesh_names_api.erl  ← the single public module
│   ├── resolve_mri/                            ← DESK: single-shot resolve / refresh
│   ├── watch_mri/                              ← DESK: push subscription registry
│   ├── describe_mri/                           ← DESK: composite query
│   ├── backlinks/                              ← DESK: reverse queries
│   ├── verify_trust_chain/                     ← DESK: 5-link state machine
│   │       verify_trust_chain.erl (+ _sup) + verify_frtl / verify_realm_directory
│   │       / verify_endorsement / verify_leaf_record / verify_host_delegation
│   ├── lookup_via_dht/                         ← DESK: macula:find_record + retry + dedup (lookup_dedup)
│   ├── cache_records/                          ← DESK: 5-layer ETS cache (cache_records / cache_invalidate / cache_ttl_sweep)
│   ├── on_record_observed_invalidate_cache/    ← DESK (PM): tombstone / RME → invalidate
│   ├── on_realm_directory_changed_warm_cache/  ← DESK (PM): realm_directory / FRTL change → invalidate
│   └── trust_anchors/                          ← DESK: realm_id → foundation_pubkey registry (the L0 layer)
└── test/
    ├── resolve_mri_SUITE.erl          watch_mri_SUITE.erl       describe_mri_SUITE.erl
    ├── backlinks_SUITE.erl            verify_trust_chain_SUITE.erl
    ├── lookup_via_dht_SUITE.erl       cache_invariants_SUITE.erl
    ├── push_invalidation_SUITE.erl    trust_anchors_SUITE.erl   library_api_SUITE.erl
```

Per the workspace `CLAUDE.md` vertical-slicing rule: each subdirectory is either a **desk** (capability with its own supervisor + worker(s)) or a **library** (functions only, no process). The slice-root supervisor supervises desk supervisors only. `library_api/` is the deliberate single-module public surface — not a horizontal layer.

## Plan reference

| Document | Sections covered here |
|----------|-----------------------|
| `PLAN_RESOLVE_MESH_NAMES_ROOT.md` | overall framing + dependency graph |
| `PLAN_RESOLVE_MESH_NAMES_PART1.md` | this slice in full (API, trust chain, push cache, PMs, tests) |
| `PLAN_RESOLVE_MESH_NAMES_PART2.md` | macula 4.3.0 SDK PR scope (`station` MRI type + `macula_z32` codec) |

Companion plan family (consumes this slice):
- `PLAN_DNS_OVER_MESH_ROOT.md` / `PLAN_DNS_OVER_MESH_PART1.md` — the Tier-2 DNS wire bridge that calls this slice's `library_api`.

## Substrate contract

Built on the macula SDK (currently **4.3.0**) + the macula-station substrate. Specifically depends on:

- `macula:put_record/2` / `macula:find_record/2` / `macula:find_records_by_type/1` (DHT) — via `lookup_via_dht`
- `macula:subscribe_records/3` (push) — via the two PMs; verified working as of macula 4.2.9 + macula-station `57f4c8d` (`macula-e2e:subscribe_records_cross_station` 6/6) and re-verified on 4.3.0 by the live harness
- `macula_record` constructors for FRTL, realm_directory, RME, station_endpoint, address_pubkey_map, hosted_address_map, host_delegation, procedure_advertisement, foundation_t3_attestation, tombstone — exported in 4.2.x+
- `macula_identity` (Ed25519, UCAN), `macula_record:sign/2` / `verify/1` / `storage_key/1`
- `macula_mri` (resource-identifier parser; `station` type added in 4.3.0)
- `macula_z32` (z-base-32 codec; new in 4.3.0)

**`macula_record:decode/1` (CBOR) is non-deterministic about payload key form** — it `binary_to_existing_atom`s text-string keys, so a DHT-round-tripped `station_endpoint` payload comes back with `host_advertised`/`alpn` as bare atoms but `quic_port` as `{text, <<"quic_port">>}`, and a scalar text value stays `{text, Bin}`-wrapped while text values inside a list come back as bare binaries. `build_verified_record` carries the payload through as-is; **VR consumers must read payload fields tolerantly** (atom ⊕ `{text, bin}` ⊕ bare-bin; unwrap `{text, V}`). See `serve_dns_over_mesh`'s `synthesize_rr_set:payload_field/4`.

**Cross-station DHT find flakes ~60% per attempt under load** (see `macula-internal/macula-station/docs/DHT_FIND_FLAKE_ATTEMPT.md`). `lookup_via_dht` polls with retry (3 attempts → ~94%, app-env tunable). Full fix needs multi-round Kademlia iterative — substrate Phase 4+.

## Verified

- `rebar3 ct --dir apps/resolve_mesh_names/test` — 83/83 (10 suites). Tampered record → `{error, sig_indeterminate}`; tombstoned member → cache invalidation per `push_invalidation_SUITE`; cache cascade invariants per `cache_invariants_SUITE`.
- `hecate-daemon/harness/run-live-dns-harness.sh` — live, no-stubs: connects a real macula V2 pool to the relay fleet, publishes a `station_endpoint` into the DHT, and `resolve_mesh_names_api:resolve/3` returns the verified record (self-rooted trust verification) + the two PMs are subscribed to the live pool. (The harness also drives `serve_dns_over_mesh` end-to-end — see `harness/README.md`.)

## Known gaps / deferred

- **Leaf-storage-key gap** — `resolve` only resolves `station` (self-rooted) and `proc` (realm chain) MRIs deterministically; `user` / `app` / `service` / `device` MRIs return `{error, {not_resolvable_yet, Type}}` because there's no MRI→storage-key mapping. Needs a realm-scoped name→pubkey index record (a macula 4.4.0 candidate) or per-type conventions.
- **`backlinks/2`** — returns `{error, backlinks_not_yet_implemented}` (honest — the SDK's RME schema has no `path` field and there's no reverse index). Same index requirement as the leaf-storage-key gap, or a realm-scoped backlink record.
- **`describe`'s `endorsements`** — `[]`; `verify_trust_chain` caches the member pubkey in L3 but not the full RME — needs a fresh fetch.
- **Per-key cache invalidation** — currently realm-coarse (a change nukes the whole realm subtree); needs a storage_key→cache_key reverse index + reconciling the L3 key shape (`{realm_id, member_pk}` per `verify_trust_chain` vs the `{realm_id, path}` cascade in `cache_invalidate:by_key`).
- **Station-MRI change delivery in `watch`** — station watchers get current-value-on-subscribe but aren't notified on `station_endpoint` changes (no realm to match against in `realm_changed`).
- **Gated on macula 4.4.0** (`dane_pin` 0x15, `coverage_proof` 0x16): proper NXDOMAIN proofs (currently a missing endorsement degrades to `{error, coverage_unknown}`); TLSA verification (skipped). Neither is on the critical path for `serve_dns_over_mesh` or `serve_https_over_mesh`.
- `compiled_in_realm_pubkeys` (realm_id → realm_pk mapping used by `verify_trust_chain`) is empty by default — will be populated from `realm_directory` scans in a follow-up; for now operator config supplies it.
