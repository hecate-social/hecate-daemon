# Push-driven cache

How `resolve_mesh_names` keeps verified results fresh: push invalidation is the
primary mechanism (the mesh notifies us when a record changes/tombstones); the
TTL sweep is a safety net for entries we missed a notification for. Plan:
`PLAN_RESOLVE_MESH_NAMES_PART1` §6. Implementation: `src/cache_records/`
(`cache_records` — the ETS tables; `cache_invalidate` — the cascade;
`cache_ttl_sweep` — the periodic sweep), `src/lookup_via_dht/` (`lookup_via_dht`
+ `lookup_dedup` — DHT primitive with retry and in-flight de-dup), and the two PM
desks `src/on_record_observed_invalidate_cache/` + `src/on_realm_directory_changed_warm_cache/`.

## The 5 layers

| Layer | Holds | Keyed by |
|-------|-------|----------|
| L1 | realm root pubkeys | realm-id (also reverse-indexed pubkey→realm-id) |
| L2 | `realm_directory` records | realm-id |
| L3 | endorsements (the member pubkey from the verified RME) | `{realm-id, member_pk}` |
| L4 | leaf records (`station_endpoint`, `procedure_advertisement`, …) | `{mri, leaf_type}` |
| L5 | composite verified results — the `verified_record()` list `resolve` returns | mri |

A successful trust-chain walk populates L1→L5 as it goes; `resolve` checks L5
first and short-circuits on a hit. Each entry carries an expiry (ms epoch,
derived from the underlying record's `expires_at`) and a version.

## Push invalidation (primary)

Two PMs subscribe to the mesh's `_dht.records.<type>.stored` push topics via
`macula:subscribe_records/3` and translate pushes into `cache_invalidate` calls:

- **`on_record_observed_invalidate_cache`** watches **tombstone** (type `0x0C`)
  and **`realm_member_endorsement`** (type `0x05`). A `realm_directory` tombstone
  (whose `superseded_key` IS the realm pubkey) → reverse-look-up the realm-id in
  L1 → `cache_invalidate:by_realm/1` (precise). An RME tombstone or version-bump
  → reverse-look-up the realm-id → invalidate that realm's subtree (the cache
  doesn't yet index L4 by signer, so realm-grain is the precision we deliver). A
  tombstone whose `superseded_type` is anything else (FRTL, a leaf type — hashed
  storage key we can't reverse) → nuke L5 (coarse but correct; RME/FRTL
  changes also force L3 re-validation on the next chain walk).
- **`on_realm_directory_changed_warm_cache`** watches **`realm_directory`**
  (type `0x03`) and **`foundation_realm_trust_list`** (type `0x0F`). A
  `realm_directory` change → reverse-look-up the realm-id → invalidate that
  realm's subtree. An FRTL change → find every realm anchored to that foundation
  (via `trust_anchors:list/0`) → invalidate each. ("Warm cache" currently means
  prompt *invalidation* on a structural change — actual pre-*fetch* is a
  follow-up; the next `resolve` does the re-walk lazily.)

`cache_invalidate` cascades downward: invalidating a realm's L1/L2 cascades to
its L3/L4/L5 entries. Invalidation is **realm-grain**, not per-key — precise
per-key invalidation needs a storage_key→cache_key reverse index (a follow-up).

**The PMs self-bootstrap.** They don't have a pool handle at boot, so on start
each polls `hecate_mesh:get_client/0` every `mesh_subscribe_retry_ms` (default
5 s) until the daemon's V2 macula pool is up (cold boot / pre-realm-join), then
subscribes to its watched types and `monitor`s the pool; if the pool dies it
re-bootstraps against whatever pool a mesh reactivation rebuilds. Once subscribed
it stops polling. (`hecate_mesh:get_client/0` — a lock-free persistent_term read
of the V2 pool — was restored for this; it had been lost in the V1→V2 mesh-client
refactor. `subscribe/1` remains as an explicit-override entry point.)

## TTL sweep (fallback)

`cache_ttl_sweep` wakes every `cache_ttl_sweep_period_ms` (default 30 s) and
evicts expired entries across all layers — the safety net for any push
notification we missed (the substrate's `subscribe_records` is best-effort).

## Cold-cache de-dup

`lookup_via_dht:find/2,3` routes every DHT lookup through `lookup_dedup`: if a
lookup for the same storage key is already in flight, the caller piggybacks on it
rather than issuing a duplicate DHT call — no thundering herd on a cold cache.
`lookup_via_dht` also retries (3 attempts, app-env tunable via
`dht_lookup_retry_attempts`/`dht_lookup_retry_delay_ms`) on `not_found`/`timeout`
to compensate the documented ~60 % per-attempt cross-station DHT flake (→ ~94 %
effective).

## Tombstones

A signed `tombstone` record supersedes prior versions for the same storage key.
Resolve treats a tombstoned leaf as `{error, name_revoked}`; the PMs treat a
tombstone push as an invalidation signal (see above).
