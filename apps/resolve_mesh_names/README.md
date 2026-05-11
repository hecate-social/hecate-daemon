# resolve_mesh_names

Tier-1 mesh-native naming service. Exposes resolve / watch / describe / verify_trust_chain / backlinks over MRIs and signed records. Push-invalidated cache. Consumed by every Tier-2 wire bridge (`serve_dns_over_mesh`, `serve_https_over_mesh`, future `serve_mdns_over_mesh`, daemon REST API, TUI naming browser).

**Status:** Phase 0 — scaffold. Every module compiles; every public function returns `{error, *_not_yet_implemented}` (or a clear empty value). The supervisor tree boots cleanly. Phase 1 fills in the lookup pipeline, trust chain, push cache, PMs, and watch subscriptions per [PLAN_RESOLVE_MESH_NAMES_PART1](https://codeberg.org/macula-internal/macula-architecture/src/branch/main/plans/PLAN_RESOLVE_MESH_NAMES_PART1.md).

## Why

Naming on the mesh has primitives DNS does not have: push notifications instead of TTL polling, signed records with first-class tombstones, composite/streaming/backlinks queries, multi-replica consensus, self-rooted identifiers, time-travel resolution. This slice exposes those mesh-native primitives idiomatically. Wire bridges (DNS, HTTPS, mDNS, REST, TUI) consume the API and translate to their own protocol shape — degrading what they must but never contaminating the naming service.

The original `serve_dns_over_mesh` plan had naming + DNS bridge fused into one slice. That fusion forced DNS shape (RRsets, TTLs, rcodes) into every consumer including HTTPS-over-mesh which has no DNS interest. This split fixes the leak at the architecture level. See the plan's decisions log for the 2026-05-11 split rationale.

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
│   ├── resolve_mesh_names_sup.erl              ← slice-root supervisor
│   ├── library_api/                            ← single import point
│   ├── resolve_mri/                            ← DESK: single-shot resolve
│   ├── watch_mri/                              ← DESK: push subscription
│   ├── describe_mri/                           ← DESK: composite query
│   ├── backlinks/                              ← DESK: reverse queries
│   ├── verify_trust_chain/                     ← DESK: 5-link state machine
│   ├── lookup_via_dht/                         ← DESK: DHT primitive + dedup
│   ├── cache_records/                          ← DESK: push-invalidated cache
│   ├── on_record_observed_invalidate_cache/    ← DESK (PM): invalidation
│   ├── on_realm_directory_changed_warm_cache/  ← DESK (PM): pre-warm
│   └── trust_anchors/                          ← DESK: foundation seed registry
└── test/
    ├── resolve_mri_SUITE.erl
    ├── watch_mri_SUITE.erl
    ├── describe_mri_SUITE.erl
    ├── backlinks_SUITE.erl
    ├── verify_trust_chain_SUITE.erl
    ├── lookup_via_dht_SUITE.erl
    ├── cache_invariants_SUITE.erl
    ├── push_invalidation_SUITE.erl
    └── library_api_SUITE.erl
```

Per the workspace `CLAUDE.md` vertical-slicing rule: each subdirectory is either a **desk** (capability with its own supervisor + worker) or a **library** (functions only, no process). The slice-root supervisor supervises desk supervisors only. `library_api/` is the deliberate single-module public surface — not a horizontal layer.

## Plan reference

| Document | Sections covered here |
|----------|-----------------------|
| `PLAN_RESOLVE_MESH_NAMES_ROOT.md` | overall framing + dependency graph |
| `PLAN_RESOLVE_MESH_NAMES_PART1.md` | this slice in full (API, trust chain, push cache, PMs, tests) |
| `PLAN_RESOLVE_MESH_NAMES_PART2.md` | macula 4.3.0 SDK PR scope (station MRI type + z32 codec) |

Companion plan family (consumes this slice):
- `PLAN_DNS_OVER_MESH_ROOT.md` — Tier-2 wire bridges that call this slice's library_api

## Substrate contract

Built on the macula SDK + macula-station substrate. Specifically depends on:

- `macula:put_record/2` / `macula:find_record/2` (DHT) — via `lookup_via_dht`
- `macula:subscribe_records/3` (push) — via the two PMs; verified working as of macula 4.2.9 + macula-station 57f4c8d (`macula-e2e:subscribe_records_cross_station` passes 6/6)
- `macula_record` constructors for FRTL, realm_directory, RME, station_endpoint, address_pubkey_map, hosted_address_map, host_delegation, procedure_advertisement, foundation_t3_attestation, tombstone — all exported in 4.2.x
- `macula_identity` (Ed25519, UCAN)
- `macula_mri` (resource identifier parser; `station` type added in 4.3.0)
- `macula_z32` (z-base-32 codec; new in 4.3.0)

**Known substrate limitation:** cross-station DHT find currently flakes at ~60% per attempt under load (see `macula-internal/macula-station/docs/DHT_FIND_FLAKE_ATTEMPT.md`). The `lookup_via_dht` desk polls with retry (3 attempts) to compensate; effective hit rate ~94%. Full fix needs multi-round Kademlia iterative — substrate Phase 4+.

## Phase 1 acceptance

The slice ships when:

- `library_api:resolve(Pool, Mri)` returns verified leaf records for every leaf type, p95 ≤ 800 ms cold and ≤ 30 ms warm
- `library_api:watch(Pool, Mri, Pid)` delivers push notifications within 1 s of underlying record changes
- `library_api:describe(Pool, Mri)` returns the composite bundle in a single call
- `library_api:verify_trust_chain(Pool, Mri, LeafType)` walks the full 5-link state machine
- Tampered records → `{error, sig_indeterminate}`, never a verified-but-wrong record
- Tombstoned member → `{error, name_revoked}` within 60 s of tombstone publication
- All Tier-2 wire bridges consume the library_api with no naming/trust state of their own

All 8 composite success criteria are listed in `PLAN_RESOLVE_MESH_NAMES_PART1` §9.

## Phase 1 deferred

- `dane_pin` (record type 0x15) and `coverage_proof` (0x16) — both need a separate spec PR in `macula-io/macula` (4.4.0). Until they ship, NXDOMAIN proofs degrade to `{error, coverage_unknown}` and TLSA verification is skipped. Neither is on the critical path for `serve_dns_over_mesh` Phase 1 or `serve_https_over_mesh` Phase 1.
