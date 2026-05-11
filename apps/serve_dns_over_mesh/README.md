# serve_dns_over_mesh

Daemon-local DNS-over-mesh resolver — a **Tier-2 wire bridge**. Translates RFC 1035 / EDNS0 queries on the synthetic `*.macula.io.` suffix into `resolve_mesh_names` calls, then synthesises an RRset from the verified record(s). Owns the wire-protocol layer only — naming, trust verification, and caching all live in `resolve_mesh_names`.

**Status:** Phase 1 complete (post-2026-05-11 split — this slice was carved out of the original fused `serve_dns_over_mesh` plan; the strategic naming asset moved to `resolve_mesh_names`). UDP / TCP / DoH transports, the qname↔MRI label algebra, the `serve_query` pipeline, RRset synthesis, and RFC 1035 / EDNS0 / EDE wire codec are all implemented; 65/65 CT green; and the whole path — including a `dig`-equivalent `nslookup` over the live `127.0.0.1:5353` socket — is verified live against the Macula mesh by `hecate-daemon/harness/run-live-dns-harness.sh`. Plan: `macula-internal/macula-architecture/plans/PLAN_DNS_OVER_MESH_PART1.md` (slimmed to bridge-only after the split).

What works today:

- **Transports** — `listen_udp` (UDP, `{active, once}`, per-query spawned worker) and `listen_tcp` (DNS-over-TCP `{packet,2}` length-prefix framing, multi-query connections per RFC 7766, idle timeout) are supervised desks. `listen_doh` (RFC 8484 DoH — `POST application/dns-message` + `GET ?dns=base64url`) is a plain Cowboy handler with no process of its own, auto-discovered by `hecate_api`'s route aggregator at `/dns-query`. All three feed the same `serve_query:handle/3`. Default bind `127.0.0.1`, ports 5353 (binding port 53 needs `CAP_NET_BIND_SERVICE` or an iptables 53→5353 redirect — handled at deploy time, not here); a bind failure degrades the listener to a `no_socket` state (logs a warning, stays alive) rather than crash-looping.
- **`serve_query/handle/3`** — the pipeline: `parse_query:parse/1` → AXFR/IXFR refusal → `classify_qname:classify/1` (not_mesh → REFUSED; label-boundary aware, so `evilmacula.io.` is not mesh) → `qname_to_mri:resolve/1` → `resolve_mesh_names_api:resolve/3` → `synthesize_rr_set:synth/4` → `compose_response:compose/1`. Maps resolve errors to rcode + RFC 8914 EDE (`name_revoked`/`endorsement_expired`/`name_not_endorsed` → NXDOMAIN, `no_trust_root`/`realm_not_trusted` → REFUSED, `{not_resolvable_yet,_}` and everything else → SERVFAIL). FORMERR for a zero-question packet; `drop` for a too-garbled one (the caller doesn't reply). The macula client pool is fetched lazily per query via `hecate_mesh:get_client/0`; when the mesh isn't connected, mesh queries answer SERVFAIL and non-mesh queries REFUSED with no pool needed.
- **qname ↔ MRI label algebra** (`qname_to_mri/`) — a dispatcher (`qname_to_mri.erl`: multi-discriminator walk + `format/1` for the reverse direction) plus per-MRI-type modules: `qname_simple` (helper), `qname_org`, `qname_user`/`app`/`service`/`device` (delegate to `qname_simple`), `qname_proc`/`qname_topic` (dot-flattening — build the MRI string directly because `macula_mri:new/3`'s segment validator rejects `.` in a segment), `qname_station` (`<z32(pubkey)>._st.macula.io.` ↔ `mri:station:<z32>`, via `macula_z32` + the macula 4.3.0 `station` MRI type), `qname_reverse_v6` (`ip6.arpa` nibble decode).
- **RRset synthesis** (`synthesize_rr_set/`) — a dispatcher (`synthesize_rr_set.erl`: `synth(QName, QType, VRs, Opts)`; ANY → NOTIMP per RFC 8482; TLSA → NOTIMP) plus per-qtype modules. `synth_aaaa`/`synth_a` — `station_endpoint.host_advertised` filtered by family; `synth_srv` — `0 0 <quic_port> <station-qname>`; `synth_txt` — `alpn=<value>`. Payload fields are read via `synthesize_rr_set:payload_field/4`, which tolerates macula's CBOR-decode key forms (atom ⊕ `{text, bin}` ⊕ bare-bin keys; unwraps a `{text, V}` value) so synthesis works on records straight off the wire, not just hand-built fixtures. `synth_soa`/`synth_ns`/`synth_ptr`/`synth_tlsa` are present but return `[]` / NOTIMP until their data sources are wired (see "Known gaps").
- **Wire codec** — `parse_query` (RFC 1035 header + question + EDNS0 OPT, compression-pointer aware) + `parse_query_edns0` (OPT-RDATA option list); `compose_response` (full RR encoding for A/AAAA/TXT/SRV/PTR/NS/CNAME/SOA/TLSA + raw; EDNS0 OPT pseudo-RR; TC=1 truncation) + `compose_ede` (RFC 8914 — cause atom → {INFO-CODE, extra-text}).
- **`library_api/serve_dns_over_mesh_api.erl`** — exposes `qname_to_mri/1` + `mri_to_qname/1` for sibling Tier-2 bridges (e.g. `serve_https_over_mesh`).

## Why

A daemon-local resolver lets stock clients (`dig`, browsers, `curl`, SSH) reach mesh-hosted resources without Macula SDK integration: mesh names become routable as ordinary DNS names under a synthetic `macula.io.` suffix; trust is `resolve_mesh_names`' concern, anchored at signed `foundation_realm_trust_list` records walked end-to-end.

This slice is deliberately a **thin wire bridge**: it owns DNS-shape concerns (RRsets, TTLs, rcodes, EDNS0, EDE) and nothing else. The original `serve_dns_over_mesh` plan fused naming + DNS into one slice, which forced DNS shape into every consumer — including the future HTTPS bridge, which has no DNS interest. The 2026-05-11 split moved the naming/trust/cache asset into `resolve_mesh_names`; this slice (and `serve_https_over_mesh`, and a possible `serve_mdns_over_mesh`) consume its `library_api`.

Sister slice `serve_https_over_mesh` (PLAN_DNS_OVER_MESH_PART2 — re-rooted on `resolve_mesh_names`, not yet scaffolded) will terminate HTTPS with a daemon-local CA and use `resolve_mesh_names:library_api` to resolve the SNI / `:authority` to an MRI + verify the trust chain.

## Layout

```
serve_dns_over_mesh/
├── README.md                          ← this file
├── docs/
│   ├── PROTOCOL_MAPPING.md            ← MRI ↔ DNS qname algebra
│   ├── TRUST_CHAIN.md                 ← (mostly delegated to resolve_mesh_names now)
│   └── EDE_CODES.md                   ← rcode + EDE map
├── src/
│   ├── serve_dns_over_mesh.app.src    ← depends on `resolve_mesh_names`
│   ├── serve_dns_over_mesh_app.erl    ← OTP application
│   ├── serve_dns_over_mesh_sup.erl    ← slice-root supervisor (listen_udp_sup + listen_tcp_sup only)
│   ├── listen_udp/                    ← DESK: UDP listener (listen_udp + listen_udp_sup)
│   ├── listen_tcp/                    ← DESK: TCP listener (listen_tcp + listen_tcp_sup)
│   ├── listen_doh/                    ← lib: RFC 8484 DoH — a Cowboy handler, no process (auto-discovered by hecate_api)
│   ├── serve_query/                   ← lib: the lookup pipeline (parse → classify → qname_to_mri → resolve → synth → compose)
│   ├── qname_to_mri/                  ← lib: label algebra — dispatcher + per-MRI-type modules
│   │       qname_to_mri.erl + qname_simple / qname_org / qname_user / qname_app / qname_service
│   │       / qname_device / qname_proc / qname_topic / qname_station / qname_reverse_v6
│   ├── classify_qname/                ← lib: mesh-eligible suffix check (label-boundary aware)
│   ├── parse_query/                   ← lib: RFC 1035 + EDNS0 wire decode (parse_query + parse_query_edns0)
│   ├── compose_response/              ← lib: rcode/flags/RR/EDNS0/EDE wire encode (compose_response + compose_ede)
│   ├── synthesize_rr_set/             ← lib: per-qtype RRset synthesis
│   │       synthesize_rr_set.erl + synth_a / synth_aaaa / synth_srv / synth_txt
│   │       / synth_soa / synth_ns / synth_ptr / synth_tlsa
│   └── library_api/serve_dns_over_mesh_api.erl  ← qname_to_mri/1 + mri_to_qname/1 for sibling bridges
└── test/
    ├── wire_codec_SUITE.erl           label_algebra_SUITE.erl       synthesize_rr_set_SUITE.erl
    ├── serve_query_SUITE.erl          listen_udp_SUITE.erl          listen_tcp_SUITE.erl
    ├── listen_doh_SUITE.erl           failure_mode_SUITE.erl
```

Per the workspace `CLAUDE.md` vertical-slicing rule: each subdirectory is either a **desk** (capability with its own supervisor + worker) or a **library** (functions only, no process). The slice-root supervisor supervises desk supervisors only — here, just `listen_udp_sup` + `listen_tcp_sup` (UDP and TCP are independent; DoH is a request-driven Cowboy handler with nothing to supervise; the qname↔MRI codec, `serve_query` pipeline, RR synthesis and response composition are pure-function modules).

App env (`serve_dns_over_mesh.app.src`): `bind` (`"127.0.0.1"`), `udp_port` / `tcp_port` (5353), `tcp_idle_timeout_ms` (30000), `doh_path` (`"/dns-query"`), `min_rr_ttl` / `max_rr_ttl` (60 / 3600 — RR TTL = clamp(record.expires_at − now, min, max)), `mesh_suffix` (`"macula.io."`), `resolve_timeout_ms` (1500).

## Plan reference

| Document | Sections covered here |
|----------|-----------------------|
| `PLAN_DNS_OVER_MESH_ROOT.md` | overall framing + dependency graph (re-rooted on `resolve_mesh_names`) |
| `PLAN_DNS_OVER_MESH_PART1.md` | this slice in full (label algebra, qtype synthesis, the serve_query pipeline, failure modes) — slimmed to bridge-only after the split |
| `PLAN_DNS_OVER_MESH_PART2.md` | sister `serve_https_over_mesh` slice (not yet scaffolded) |
| `PLAN_DNS_OVER_MESH_PART3.md` | UX modes + operator CLI + rollout phases |

The Tier-1 naming service this slice consumes: `PLAN_RESOLVE_MESH_NAMES_{ROOT,PART1,PART2}.md` + `apps/resolve_mesh_names/README.md`.

## Substrate contract

- **`resolve_mesh_names:library_api`** — `resolve_mesh_names_api:resolve/3` (the `serve_query` pipeline) and (for `describe`-style queries, future) `describe/3`. This slice carries no naming, trust, or cache state of its own.
- **macula** (currently 4.3.0) — only indirectly: the listeners fetch the V2 pool via `hecate_mesh:get_client/0` and pass it to `serve_query` → `resolve_mesh_names_api:resolve` (which does the DHT lookups + trust verification). Also `macula_z32` / `macula_mri` for the `station` qname↔MRI algebra. **`macula_record:decode/1` (CBOR) is non-deterministic about payload key form** (it `binary_to_existing_atom`s text keys, so `host_advertised`/`alpn` come back as bare atoms but `quic_port` as `{text, <<"quic_port">>}`, and scalar text values stay `{text, Bin}`-wrapped while list elements come back bare) — `synthesize_rr_set:payload_field/4` reads payload fields tolerantly so the `synth_*` modules work on real wire records, not just CT fixtures.
- The cross-station DHT find flake (~60%/attempt) is `resolve_mesh_names`' concern now — its `lookup_via_dht` retries (3 attempts → ~94%).

## Verified

- `rebar3 ct --dir apps/serve_dns_over_mesh/test` — 65/65 (8 suites). Signature tampering on the wire → SERVFAIL + EDE (never cache poisoning — and this slice holds no cache); zero-question → FORMERR; garbled → `drop`; AXFR/IXFR → REFUSED + EDE; non-mesh qname → REFUSED; the qtype synthesisers (incl. a CBOR-decoded-payload fixture); the UDP/TCP/DoH listeners.
- `hecate-daemon/harness/run-live-dns-harness.sh` — live, no-stubs: a real macula V2 pool to the relay fleet, a `station_endpoint` published into the DHT, then `serve_query/3` AAAA + SRV in-process **and** `nslookup -port=5353 -type=AAAA <z32>._st.macula.io 127.0.0.1` (the `dig` equivalent) over the live `listen_udp` socket → the advertised `2001:db8:dead:beef::1`. See `harness/README.md`.

## Known gaps / deferred

- **`synth_soa` / `synth_ns` / `synth_ptr`** — return `[]` (→ NODATA, a valid "exists, no such record" answer, not a lie) until their data sources are wired: SOA needs `resolve_mesh_names` to resolve `mri:realm:...` (a `realm_directory` VR); NS needs the `realm_stations` record; PTR needs the `ip6.arpa` reverse path routed through `resolve_mesh_names` (`qname_reverse_v6:decode_qname/1` is done; `resolve/1` returns `reverse_v6_lookup_required`).
- **`user` / `app` / `service` / `device` qnames** → `dig alice._u.acme.macula.io` is SERVFAIL + EDE(`not_resolvable_yet`) — blocked on the leaf-storage-key gap in `resolve_mesh_names` (no MRI→storage-key mapping yet). `station` and `proc` qnames resolve.
- **Gated on macula 4.4.0** (`dane_pin` 0x15, `coverage_proof` 0x16): TLSA synthesis (currently NOTIMP + EDE(`tlsa_unsupported`)); proper NXDOMAIN proofs (a missing endorsement currently degrades to SERVFAIL + EDE(`coverage_unknown`)).
- **DoH `Cache-Control`** — currently `no-store`; RFC 8484 §5.1 wants `max-age` = the answer's minimum TTL (a follow-up).
- **DoQ (DNS-over-QUIC, RFC 9250)** — a Phase-2 transport: a thin wrapper over the daemon's existing QUIC stack feeding the same `serve_query`.
- **`serve_https_over_mesh`** (PLAN_DNS_OVER_MESH_PART2) — re-rooted on `resolve_mesh_names`, not yet scaffolded.
