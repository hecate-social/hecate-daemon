# Trust chain — the 5-link verification

`verify_trust_chain/` is the desk that takes an MRI + leaf-record type and
returns either a verified leaf record or a typed `{error, atom()}`. Unverified
records never escape this slice. Wire bridges (`serve_dns_over_mesh`, …) translate
the result to their own protocol shape at their own boundary.

**Plan:** `PLAN_RESOLVE_MESH_NAMES_PART1` §5 (state machine, revocation
primitives, cross-realm trust, bootstrap) and §0 (the divergences below).
**Implementation:** `src/verify_trust_chain/` — the driver `verify_trust_chain.erl`
plus the per-link verifiers `verify_frtl`, `verify_realm_directory`,
`verify_endorsement`, `verify_leaf_record`, `verify_host_delegation`.

## The walk (bottom-up)

The driver is a **fold over a list of step functions**; each step reads what it
needs from a `Ctx` map, populates more, and returns `{ok, NewCtx}` or
`{error, Reason}` — the fold short-circuits on the first failure. State sequence:

```
need_anchor → need_frtl → have_frtl → need_dir → have_dir →
need_leaf → have_leaf → need_endorse → have_endorse →
[need_hd?] → verified
```

| Step | What it does |
|------|--------------|
| `need_anchor` | look up the foundation pubkey for the MRI's realm in `trust_anchors` (the L0 layer — ETS, bootstrapped from app env `compiled_in_seeds`). No anchor → `{error, no_trust_root}`. |
| `need_frtl` → `have_frtl` | fetch + verify the `foundation_realm_trust_list` (type `0x0F`, keyed under domain `"foundation_realm_trust_list"`), signed by the foundation pubkey; check the realm's root pubkey is in the FRTL's `realms_trusted` list, not in `realms_revoked`, and the FRTL is within its validity window (with `grace_window_ms` clock-skew tolerance, default 300 s). Fails: `realm_not_trusted`, `trust_list_unavailable`, `trust_list_stale`. |
| `need_dir` → `have_dir` | fetch + verify the `realm_directory` (type `0x03`) — **its storage key IS the realm pubkey** (no domain hash) — signed by the realm root. Fails: `realm_dir_unavailable`, `realm_dir_bogus`. |
| `need_leaf` → `have_leaf` | fetch + verify the leaf record (`station_endpoint`, `procedure_advertisement`, …) at the caller-supplied / type-derived storage key, signed by **the leaf's own pubkey** (the leaf's `key` field IS the member's signing pubkey IS the `member_pk`). Fails: `station_not_announced` / leaf-specific, `sig_indeterminate`, `integrity_violation`. |
| `need_endorse` → `have_endorse` | fetch + verify the `realm_member_endorsement` (RME, type `0x05`, keyed under domain `"member_endorsement"` as `sha256("member_endorsement" ‖ realm_pk ‖ member_pk)` — **which is why the leaf is fetched first: we need `member_pk`**), signed by the realm root, covering this member, within its validity window. Fails: `name_not_endorsed`, `endorsement_expired`, `name_revoked` (tombstoned), `coverage_unknown` (no endorsement *and* no coverage proof — until macula 4.4.0's `coverage_proof` ships, this degrades to `{error, coverage_unknown}` rather than fabricating `name_revoked`). |
| `[need_hd?]` | if the leaf says the record is *hosted* (a `hosted_address_map`, type `0x14` — daemon's address hosted by some station), fetch + verify the `host_delegation` chaining the hosting station's authority to the daemon. Fails: `delegation_invalid`. Skipped for non-hosted leaves (the common case). |
| `verified` | build the verified-record map (`record_type`, `mri`, `payload`, `signer_pubkey`, `chain` metadata, `expires_at`, `version`, `observed_at`) and write the L4 leaf + L5 composite cache entries. |

Every fetch step **reads `cache_records` first** (L1 = realm pubkeys, L2 = realm
directories, L3 = endorsements, L4 = leaf records), **falls back to
`lookup_via_dht` on a miss** (which retries — 3 attempts — to compensate the
~60 % per-attempt cross-station DHT flake), and **populates the cache on
success**. Signature verification is real Ed25519 via `macula_record:verify/1`
(which also checks expiry). All fail edges map to typed `{error, atom()}`
matching `PLAN_RESOLVE_MESH_NAMES_PART1` §6; `serve_dns_over_mesh` maps those to
DNS rcode + EDE (see `apps/serve_dns_over_mesh/docs/EDE_CODES.md`).

## Station MRIs skip the chain

A `mri:station:<z32>` resolves **self-rooted** (`resolve_mri:resolve_station/4`):
fetch the `station_endpoint` record at `sha256("station_endpoint" ‖ pubkey)`,
require its `key` to equal the pubkey from the MRI, and verify the self-signed
signature against that same pubkey. No realm, no FRTL, no `realm_directory`, no
RME — a station is its own trust root. `mri:proc:...` resolves via the full chain
above (leaf type `procedure_advertisement`, storage-key seed = the MRI string).
`user`/`app`/`service`/`device` MRIs aren't resolvable yet — no MRI→storage-key
mapping (a macula 4.4.0 candidate) — and return `{error, {not_resolvable_yet, Type}}`.

## SDK schema divergences from PLAN PART1 §5.x

Recorded in the `verify_*` module headers; the implemented code follows the SDK:

- The walk is **bottom-up** (`need_leaf` before `need_endorse`), not the top-down
  sketch in §5.2 — because the RME storage key needs `member_pk`, which the leaf
  carries.
- The **FRTL has a flat `realms_trusted` pubkey list**, not a realm-name→pubkey
  map.
- **SDK RMEs have no `path` field** — endorsements are realm-wide, not
  path-scoped.
- The **`realm_directory` storage key IS the realm pubkey** (no domain hash).
- The **RME storage domain is `"member_endorsement"`** (not `"rme_member_endorse"`
  as some earlier sketches had it).
