# harness/ — live verification harness

A single, opt-in, **no-stubs** verification of the `resolve_mesh_names` Tier-1
mesh-native naming service and the `serve_dns_over_mesh` DNS wire bridge,
exercised against the **live** Macula relay/station fleet.

It is **not** a CT suite (it needs the live mesh + internet). It is not run in
CI. Run it by hand when you want to confirm the resolve→DNS path works
end-to-end on real infrastructure.

## What it does

1. `application:ensure_all_started(macula)` — crypto + the macula SDK (loads the
   Quinn QUIC NIF). No reckon_db, no cowboy, no daemon weight.
2. `macula:connect(Relays, #{})` — a real V2 `macula_client` pool to the live
   relays; waits until a station is connected (a DHT probe stops timing out).
3. Stashes the pool in `persistent_term:get({hecate_mesh_client, pool})` — the
   same key `hecate_mesh:get_client/0` reads, so the DNS listeners and the
   `resolve_mesh_names` cache-invalidation PMs pick it up.
4. Starts `resolve_mesh_names_sup` and `serve_dns_over_mesh_sup` directly (the
   desks + the UDP/TCP DNS listeners) — no full `hecate` application.
5. Generates a fresh Ed25519 identity, builds + self-signs a
   `station_endpoint` record (`host_advertised = [2001:db8:dead:beef::1]`,
   `quic_port = 4433`, `alpn = macula/1` — the RFC 3849 doc prefix, so the
   record is unmistakably a transient test artefact), and `macula:put_record/2`s
   it into the live DHT.
6. Verifies it resolves back through every layer:
   - **(a)** `macula:find_record/2` — raw DHT round-trip
   - **(b)** `resolve_mesh_names_api:resolve/3` — Tier-1 resolve + the
     self-rooted station trust verification (`verify` against the pubkey in the
     MRI) + L4/L5 cache write
   - **(c)** `serve_query:handle/3` — the DNS wire bridge, the exact code path
     `listen_udp`/`listen_tcp`/`listen_doh` invoke: RFC 1035 query bytes in →
     response bytes out, decoded for AAAA + SRV
   - **(d)** `nslookup -port=<port> -type=AAAA <z32>._st.macula.io 127.0.0.1` —
     a real external DNS client over the live UDP socket; true end-to-end
   - **(e)** the two cache-invalidation PMs (`on_record_observed_invalidate_cache`,
     `on_realm_directory_changed_warm_cache`) actually subscribed to the pool —
     verifies the integration wiring in commit `8be7a58`
7. Prints a PASS/FAIL table and a verdict, then `halt`s.

## Why it doesn't trip the problems the release run hit

- **No Erlang distribution.** A bare `erl` node (`nonode@nohost`) — no
  `-name`/`-sname`, so no epmd registration, so no libcluster/`*@host00.lab`
  cluster-discovery flood.
- **No `-heart`.** No resurrection crash-loop on `Ctrl-C`/exit.
- **No release env-var substitution.** It runs `erl` directly with an explicit
  `-pa` code path — never touches `config/vm.args`.
- **No disk writes.** No reckon_db, no sqlite, no `~/.hecate`. Runs in a
  throwaway `/tmp` cwd that the wrapper deletes on exit. The published
  `station_endpoint` self-expires (5 min TTL).

## Running it

```sh
harness/run-live-dns-harness.sh
```

Options:

```
--relays URL,URL,...   relay/station URLs (default: station-be-{brussels,antwerp,hasselt}.macula.io:4433)
--port N               UDP port for the DNS listener (default: 5353)
--keep SECONDS         after the report, keep the listener up this long for manual poking (default: 0)
```

(Same as the env vars `HARNESS_RELAYS` / `HARNESS_DNS_PORT` / `HARNESS_KEEP_ALIVE_S`.)

With `--keep 60` the harness prints the test name and stays up, so you can also
run the literal query yourself:

```sh
nslookup -port=5353 -type=AAAA <z32>._st.macula.io 127.0.0.1
doggo <z32>._st.macula.io @127.0.0.1:5353 AAAA          # `dig` is aliased to doggo on this box
```

(`<z32>` is printed in the harness output.)

## Layout

```
harness/
├── README.md                     ← this file
├── run-live-dns-harness.sh        ← wrapper: build, compile the module, run a bare erl
├── src/live_dns_harness.erl       ← the harness module
└── ebin/                          ← compiled output (gitignored)
```

## Expected result: PASS

```
[PASS]  raw DHT round-trip (find_record)
[PASS]  Tier-1 resolve returns the v6 record
[PASS]  DNS AAAA answer carries the v6 address
[PASS]  DNS SRV answer is non-empty
[PASS]  both cache PMs subscribed to the pool
[PASS]  external DNS client returns the v6
VERDICT: PASS — resolve_mesh_names + serve_dns_over_mesh verified live against the mesh, no stubs.
```

(A `FAIL` here means either the live mesh is unreachable / broken, or a real
regression — read the per-check lines. On its very first run this harness caught
a `serve_dns_over_mesh` bug the unit tests missed: `macula_record:decode/1` (CBOR)
`binary_to_existing_atom`s text-string payload keys, so a CBOR-round-tripped
`station_endpoint` payload comes back with mixed key forms — `host_advertised` /
`alpn` as bare atoms, `quic_port` as `{text, <<"quic_port">>}` — and the
`synth_*` modules read only the `{text, ...}` form, so AAAA/TXT came back empty
while the CT fixtures' `{text, ...}`-keyed records masked it. Fixed: the `synth_*`
modules now read payload fields via `synthesize_rr_set:payload_field/4`, which
tolerates atom ⊕ `{text, bin}` ⊕ bare-bin keys and unwraps `{text, V}` values.)

## Caveats

- Needs IPv6 connectivity to the station fleet (the `station-be-*.macula.io`
  hosts are v6-only).
- The cross-station DHT find is documented to flake ~60% per attempt; the
  harness retries `put_record`/`find_record` and `resolve_mesh_names`'s own
  `lookup_via_dht` retries internally, so a transient flake shouldn't fail the
  run — but a persistently broken mesh will.
- It resolves a **station** MRI (`mri:station:<z32>` ↔ `<z32>._st.macula.io`),
  which is self-rooted — no realm trust chain. Verifying a `user`/`app`/`service`
  MRI through the realm chain is blocked on the leaf-storage-key gap (no
  MRI→storage-key mapping yet); a `proc` MRI is resolvable but needs a realm with
  a published `realm_directory` + endorsements, which this harness doesn't set up.
```
