# Failure modes — rcode + EDE

How `serve_dns_over_mesh` turns an internal failure into a DNS response: an
**rcode** (NOERROR / NXDOMAIN / REFUSED / SERVFAIL / NOTIMP / FORMERR — or no
reply at all) plus, where useful, an **EDE** (Extended DNS Errors, RFC 8914) — a
16-bit INFO-CODE + a human-friendly EXTRA-TEXT string carried inside the EDNS0
OPT pseudo-RR. Plan: `PLAN_DNS_OVER_MESH_PART1` §6. Implementation:
`src/serve_query/serve_query.erl` (rcode + cause selection), `src/compose_response/compose_ede.erl`
(cause → INFO-CODE + text, and the wire `OPT-OPTION` encoding via `option/2`;
`info/1` is the lookup without wire encoding).

## rcode by situation (`serve_query.erl`)

| Situation | rcode | EDE cause |
|-----------|-------|-----------|
| Resolved OK — RRset synthesised | NOERROR | — |
| Name exists, no record of this qtype (`synthesize_rr_set` → `nodata`) | NOERROR + empty answer | — |
| Query has zero questions | FORMERR (id echoed) | — |
| Packet too garbled to answer | *no reply* (`drop`) | — |
| `QTYPE = ANY` (RFC 8482 §6) | NOTIMP | — (bare) |
| `QTYPE = TLSA` (`dane_pin` not in macula yet) | NOTIMP | `tlsa_unsupported` |
| `QTYPE = AXFR` / `IXFR` | REFUSED | `zone_transfer_disabled` |
| qname not under the mesh suffix | REFUSED | `not_in_mesh_suffix` |
| qname malformed / too long (`qname_to_mri` reject) | REFUSED | `malformed_qname` / `name_too_long` |
| mesh not connected (no pool) | SERVFAIL | `dht_timeout` |
| `resolve` → `{error, name_revoked}` | NXDOMAIN | `name_revoked` |
| `resolve` → `{error, endorsement_expired}` | NXDOMAIN | `endorsement_expired` |
| `resolve` → `{error, name_not_endorsed}` | NXDOMAIN | `name_not_endorsed` |
| `resolve` → `{error, no_trust_root}` | REFUSED | `no_trust_root` |
| `resolve` → `{error, realm_not_trusted}` | REFUSED | `realm_not_trusted` |
| `resolve` → `{error, {not_resolvable_yet, _Type}}` | SERVFAIL | `not_resolvable_yet` |
| `resolve` → `{error, sig_indeterminate}` (tampered record) | SERVFAIL | `sig_indeterminate` |
| `resolve` → `{error, _Other}` (e.g. `station_not_announced`, `dht_timeout`, `coverage_unknown`) | SERVFAIL | the cause atom |

Note `not_resolvable_yet` and `coverage_unknown` are placeholders: the former
covers `user`/`app`/`service`/`device` qnames until `resolve_mesh_names` gets a
MRI→storage-key mapping; the latter is the honest "I couldn't prove this name
doesn't exist" answer until macula 4.4.0 ships `coverage_proof` (NSEC analogue) —
SERVFAIL beats a forged NXDOMAIN.

## cause → INFO-CODE + EXTRA-TEXT (`compose_ede:info/1`)

INFO-CODE numbers are RFC 8914 §5.2 registry codes; the parenthetical is the
DNSSEC/iana name the code targets (per `compose_ede.erl`'s comments). `option/2`
appends an optional `:<detail>` to the text (e.g. a realm-id for `realm_not_trusted`).
`none` → no EDE option (clean answer).

| cause | INFO-CODE | EXTRA-TEXT | (registry name targeted) |
|-------|:---------:|------------|--------------------------|
| `no_trust_root` | 18 | `no_trust_root` | Prohibited |
| `trust_list_unavailable` | 22 | `trust_list_unavailable` | No Reachable Authority |
| `trust_list_stale` | 22 | `trust_list_stale` | No Reachable Authority |
| `realm_not_trusted` | 18 | `realm_not_trusted` | Prohibited |
| `realm_dir_unavailable` | 22 | `realm_dir_unavailable` | No Reachable Authority |
| `realm_dir_bogus` | 6 | `realm_dir_bogus` | DNSSEC Bogus |
| `name_not_endorsed` | 9 | `name_not_endorsed` | DNSSEC Missing (analogue) |
| `coverage_unknown` | 22 | `coverage_unknown` | No Reachable Authority |
| `endorsement_expired` | 26 | `endorsement_expired` | Stale Answer (analogue) |
| `name_revoked` | 6 | `name_revoked` | DNSSEC Bogus |
| `sig_indeterminate` | 6 | `sig_indeterminate` | DNSSEC Bogus |
| `delegation_invalid` | 6 | `delegation_invalid` | DNSSEC Bogus |
| `clock_skew` | 23 | `clock_skew` | Stale NXDOMAIN (analogue) |
| `dht_timeout` | 22 | `dht_timeout` | No Reachable Authority |
| `lookup_dedup_timeout` | 22 | `dht_timeout` | No Reachable Authority |
| `station_not_announced` | 22 | `station_not_announced` | No Reachable Authority |
| `integrity_violation` | 6 | `integrity_violation` | DNSSEC Bogus |
| `zone_transfer_disabled` | 18 | `zone_transfer_disabled` | Prohibited |
| `name_too_long` | 0 | `name_too_long` | Other |
| `not_in_mesh_suffix` | 0 | `not_in_mesh_suffix` | Other |
| `malformed_qname` | 0 | `malformed_qname` | Other |
| `tlsa_unsupported` | 0 | `tlsa_unsupported` | Other |
| `{not_resolvable_yet, _}` | 0 | `not_resolvable_yet` | Other |
| *(anything else)* | 0 | `other` | Other |

## Wire form

`compose_ede:option(Cause, Detail)` →
`OPTION-CODE(2)=15 ‖ OPTION-LENGTH(2) ‖ INFO-CODE(2) ‖ EXTRA-TEXT` — appended
inside the OPT pseudo-RR's RDATA by `compose_response`. The OPT pseudo-RR also
carries the negotiated UDP payload size; `compose_response` sets TC=1 and
truncates the answer when the response would exceed it.
