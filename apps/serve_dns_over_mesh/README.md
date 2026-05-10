# serve_dns_over_mesh

Daemon-local DNS-over-mesh resolver. Translates RFC 1035 queries on `*.macula.io.` qnames into Macula DHT lookups + signed-record verification.

**Status:** Phase 0 — scaffold. Every module compiles; every function returns `{error, not_yet_implemented}` (or a clear empty value). The supervisor tree boots cleanly. Phase 1 fills in the listeners, label algebra, trust chain, caches, and process managers per `macula-internal/macula-architecture/plans/PLAN_DNS_OVER_MESH_PART1.md`.

## Why

A daemon-local resolver lets stock clients (`dig`, browsers, `curl`, SSH) reach mesh-hosted resources without Macula SDK integration. Mesh names become routable as ordinary DNS names with a synthetic `macula.io.` suffix; trust is anchored at signed `foundation_realm_trust_list` records walked end-to-end at every query.

Sister slice `serve_https_over_mesh` (separate scaffold; PLAN_DNS_OVER_MESH_PART2) terminates HTTPS with a daemon-local CA and uses this slice's `library_api/` to resolve the SNI / `:authority` to an MRI + verify the trust chain.

## Layout

```
serve_dns_over_mesh/
├── README.md                                   ← this file
├── docs/
│   ├── PROTOCOL_MAPPING.md                     ← MRI ↔ DNS qname algebra
│   ├── TRUST_CHAIN.md                          ← state machine
│   └── EDE_CODES.md                            ← rcode + EDE map
├── src/
│   ├── serve_dns_over_mesh.app.src
│   ├── serve_dns_over_mesh_app.erl             ← OTP application
│   ├── serve_dns_over_mesh_sup.erl             ← slice-root supervisor
│   ├── listen_udp_53/                          ← DESK: UDP/53 listener
│   ├── listen_tcp_53/                          ← DESK: TCP/53 listener
│   ├── listen_doh/                             ← DESK: DoH listener
│   ├── parse_query/                            ← lib: RFC 1035 + EDNS0 wire decode
│   ├── classify_qname/                         ← lib: mesh-eligible? short-circuit non-mesh
│   ├── resolve_qname_to_mri/                   ← lib: label algebra (per-type rules)
│   ├── lookup_record_in_dht/                   ← DESK: DHT find + in-flight de-dup
│   ├── verify_trust_chain/                     ← lib: 5-link state machine
│   ├── synthesize_rr_set/                      ← lib: per-qtype encoders
│   ├── compose_response/                       ← lib: rcode/flags/EDNS0/EDE wire encode
│   ├── cache_positive/                         ← DESK: ETS owner — resolved RRsets
│   ├── cache_negative/                         ← DESK: ETS owner — NXDOMAIN proofs
│   ├── refresh_authority/                      ← DESK: background near-expires_at refresh
│   ├── on_record_observed_invalidate_cache/    ← DESK (PM): cache invalidation
│   ├── on_realm_directory_changed_warm_cache/  ← DESK (PM): cache pre-warm
│   └── library_api/                            ← lib: cross-slice contract
└── test/
    ├── label_algebra_SUITE.erl                 ← scaffold; Phase 1 fills cases
    ├── trust_chain_SUITE.erl
    ├── lookup_flow_SUITE.erl
    ├── cache_invariants_SUITE.erl
    └── failure_mode_SUITE.erl
```

Per the workspace `CLAUDE.md` vertical-slicing rule: each subdirectory is either a **desk** (capability with its own supervisor + worker) or a **library** (functions only, no process). The slice-root supervisor supervises desk supervisors only.

## Plan reference

| Document | Sections covered here |
|----------|-----------------------|
| `macula-internal/macula-architecture/plans/PLAN_DNS_OVER_MESH_ROOT.md` | overall framing + dependency graph |
| `…/PLAN_DNS_OVER_MESH_PART1.md` | this slice in full (label algebra, trust chain, lookup flow, failure modes, qtype synthesis) |
| `…/PLAN_DNS_OVER_MESH_PART2.md` | sister `serve_https_over_mesh` slice |
| `…/PLAN_DNS_OVER_MESH_PART3.md` | UX modes + operator CLI + rollout phases |

## Substrate contract

Built on the Macula SDK + macula-station substrate. Specifically depends on:

- `macula:put_record/2` / `macula:find_record/2` (DHT — verified by `macula-e2e:dht_put_find` probe)
- `macula:subscribe_records/3` (cross-station — verified by `macula-e2e:subscribe_records_cross_station` probe; works as of macula `v4.2.9` + macula-station `57f4c8d`)
- Tombstone propagation (verified by `macula-e2e:cross_station_tombstone_propagation` probe)
- `macula_record` (PKARR-style signed records, all trust-chain types)
- `macula_identity` (Ed25519, UCAN)
- `macula_mri` (resource identifier parser)

**Known substrate limitation:** cross-station DHT find currently flakes at ~60% per attempt under load (see `macula-internal/macula-station/docs/DHT_FIND_FLAKE_ATTEMPT.md`). The DNS slice's `lookup_record_in_dht` desk MUST poll-with-retry to compensate; one retry brings effective hit rate to ~84%, two to ~94%. Full fix needs multi-round Kademlia iterative (Phase 4+ scope).

## Phase 1 acceptance

The slice ships when:

- `dig alice._u.acme.macula.io @127.0.0.1 -p 5353` returns AAAA + TLSA records
- `dig -x <fc00::abc>` returns PTR pointing to the station's `_st` name
- `hecate dns trust verify io.macula` walks the full chain reporting OK
- Signature tampering on the wire causes SERVFAIL + EDE("sig_indeterminate") never cache poisoning
- Tombstoning a realm member flips queries to NXDOMAIN within 60 s
- Cold lookup p95 ≤ 800 ms; warm cached p95 ≤ 30 ms

All ten composite success criteria are listed in the plan ROOT.

## Phase 1 deferred

- `dane_pin` (record type 0x15) and `coverage_proof` (0x16) — both need a separate spec PR in `macula-io/macula`. Until they ship, NXDOMAIN proofs degrade to SERVFAIL+EDE("coverage_unknown") and TLSA synthesis is skipped.
