# Trust chain — not in this slice

`serve_dns_over_mesh` does **no** trust verification of its own. Since the
2026-05-11 split, the trust chain (foundation seed → FRTL → `realm_directory` →
endorsement → leaf record → optional `host_delegation`) lives entirely in the
Tier-1 `resolve_mesh_names` slice — its `verify_trust_chain/` desk (the
fold-over-steps dispatcher `verify_trust_chain.erl` + the verifiers
`verify_frtl` / `verify_realm_directory` / `verify_endorsement` /
`verify_leaf_record` / `verify_host_delegation`). The walk is **bottom-up**
(anchor → FRTL → realm_directory → **leaf → endorsement** → `[host_delegation]`
→ finalise), because the SDK's RME storage key is `sha256(realm_pk ‖ member_pk)`
so the member pubkey (= the leaf record's `key`) is needed before the RME can be
fetched.

This slice calls `resolve_mesh_names_api:resolve/3` (in `serve_query/serve_query.erl`),
gets back either verified records or a typed `{error, atom()}`, and maps that to
a DNS response. The only "trust"-shaped thing this slice owns is **that mapping**:

| `resolve_mesh_names_api:resolve/3` result | DNS rcode | EDE (RFC 8914) |
|-------------------------------------------|-----------|----------------|
| `{ok, VRs}` (verified leaf record(s)) | NOERROR | — (RRset synthesised from the verified records) |
| `{error, name_revoked}` | NXDOMAIN | `name_revoked` |
| `{error, endorsement_expired}` | NXDOMAIN | `endorsement_expired` |
| `{error, name_not_endorsed}` | NXDOMAIN | `name_not_endorsed` |
| `{error, no_trust_root}` | REFUSED | `no_trust_root` |
| `{error, realm_not_trusted}` | REFUSED | `realm_not_trusted` |
| `{error, {not_resolvable_yet, _Type}}` | SERVFAIL | `not_resolvable_yet` |
| `{error, sig_indeterminate}` (tampered record) | SERVFAIL | `sig_indeterminate` |
| `{error, _Other}` (e.g. `station_not_announced`, `dht_timeout`) | SERVFAIL | the cause atom |

(`coverage_unknown` is the placeholder until macula 4.4.0 ships `coverage_proof`:
a missing endorsement degrades to SERVFAIL + EDE(`coverage_unknown`) rather than
a forged NXDOMAIN. See `EDE_CODES.md` for the full cause-atom → INFO-CODE table.)

## Where the real content is

- **Slice-internal view** — `apps/resolve_mesh_names/docs/TRUST_CHAIN.md`
- **Implementation** — `apps/resolve_mesh_names/src/verify_trust_chain/`
- **Plan** — `PLAN_RESOLVE_MESH_NAMES_PART1.md` §5 (the state machine, revocation
  primitives, cross-realm trust, bootstrap) and §0 (the SDK-schema divergences:
  FRTL flat `realms_trusted`, no RME `path`, `realm_directory` storage-key = the
  realm pubkey, RME storage domain `"member_endorsement"`)
- **The error → rcode/EDE mapping above** — `apps/serve_dns_over_mesh/src/serve_query/serve_query.erl`
