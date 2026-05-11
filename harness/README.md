# harness/ — live mesh tools

Opt-in, **no-stubs** scripts that talk to the **live** Macula relay/station fleet.
Not CT suites, not run in CI — run them by hand.

| script | what it does |
|--------|--------------|
| `run-live-dns-harness.sh` | end-to-end **verification** of `resolve_mesh_names` + `serve_dns_over_mesh`: publish a record, resolve it back through every layer, PASS/FAIL table. |
| `mesh-weather.sh` | a **read-only snapshot** of the mesh from this vantage point — pool identity, this box's geo, the stations it seeds from with city / IPv6 / ping RTT. |
| `mesh-propagation.sh` | a **two-role probe** — `--publish` here, `--resolve <z32>` on another box — measuring how long a record takes to cross the mesh (and the great-circle distance between the two vantages). |
| `demo.sh` | a **narrated walk-through** for screencasts / showing people: connect → mint an identity → publish → resolve (Tier-1) → resolve over DNS. |

All four run in a bare `erl` node — **no Erlang distribution** (no `-name`/`-sname` → no epmd registration → no libcluster / `*@host00.lab` cluster-discovery flood), **no `-heart`** (no resurrection crash-loop), **no disk writes** (no reckon_db / sqlite / `~/.hecate` — they run in a throwaway `/tmp` cwd the wrapper deletes on exit). Any record they publish is a transient test artefact under the RFC 3849 documentation prefix (`2001:db8::/32`) and self-expires (~5-min TTL).

Shared plumbing lives in `harness/_common.sh` (build / compile-helper / bare-erl-launch / TTY-aware ANSI colours) and `harness/src/harness_mesh.erl` (connect-with-retry, `macula:status` as a map, z32 / hex, host-of-url / city-of-host, ping RTT, DNS v6 resolve, geo-from-env, haversine, a colour + aligned-table renderer). `harness/ebin/` is gitignored.

Common env: `HARNESS_RELAYS=url,url,...` (default `station-be-{brussels,antwerp,hasselt}.macula.io:4433`); `HECATE_GEO_CITY` / `HECATE_GEO_LAT` / `HECATE_GEO_LNG` (this box's geo, where relevant); `NO_COLOR=1` to disable colour.

---

## `run-live-dns-harness.sh` — the verification harness

```sh
harness/run-live-dns-harness.sh [--relays URL,...] [--port N] [--keep SECONDS]
```

`ensure_all_started(macula)` → `macula:connect` (waits for a station) → stash the pool in `persistent_term:{hecate_mesh_client, pool}` (where `hecate_mesh:get_client/0`, the DNS listeners, and the cache-invalidation PMs read it) → start `resolve_mesh_names_sup` + `serve_dns_over_mesh_sup` (no full `hecate` app) → publish a fresh self-signed `station_endpoint` → check it resolves back:

- **(a)** `macula:find_record/2` — raw DHT round-trip
- **(b)** `resolve_mesh_names_api:resolve/3` — Tier-1 resolve + self-rooted station trust verification + L4/L5 cache
- **(c)** `serve_query:handle/3` — the DNS wire bridge (the exact code path `listen_udp`/`listen_tcp`/`listen_doh` invoke), in-process, AAAA + SRV
- **(d)** `nslookup -port=<port> -type=AAAA <z32>._st.macula.io 127.0.0.1` — a real external DNS client over the live UDP socket
- **(e)** the two cache-invalidation PMs subscribed to the pool (verifies the `8be7a58` wiring — `hecate_mesh:get_client/0` + PM bootstrap)

Prints a coloured PASS/FAIL table; exits non-zero on FAIL. `--keep N` leaves the listener up for N s so you can `nslookup`/`doggo` it yourself. `HARNESS_DEBUG=1` adds payload/VR dumps. **Expected verdict: PASS** — a FAIL means the live mesh is unreachable/broken, or a real regression.

> Its very first run caught a `serve_dns_over_mesh` bug the unit tests missed: `macula_record:decode/1` (CBOR) `binary_to_existing_atom`s text-string payload keys, so a CBOR-round-tripped `station_endpoint` payload comes back with mixed key forms (`host_advertised`/`alpn` as bare atoms, `quic_port` as `{text, <<"quic_port">>}`); the `synth_*` modules read only the `{text, ...}` form → empty AAAA, masked by the CT fixtures using the same form. Fixed in `828c04d` — `synthesize_rr_set:payload_field/4` reads tolerantly (atom ⊕ `{text, bin}` ⊕ bare-bin; unwraps `{text, V}`).

---

## `mesh-weather.sh` — the mesh from this vantage point

```sh
harness/mesh-weather.sh [--relays URL,...]
```

Connects a transient pool, then prints (read-only, no PASS/FAIL): this vantage's host + the pool's z32 identity + this box's geo + healthy/failed link counts; and a table of the stations it seeds from — city (parsed from the host name), IPv6, ping min/avg RTT (the honest "distance"), reach — sorted by RTT. Run it here, `scp` it to another box and run it there, eyeball both. (A transient pool only knows the *seeds* it was handed — the full world-wide relay fleet w/ geo-distances lives in `macula_relay_discovery` on a connected daemon; not wired into the transient pool yet.)

---

## `mesh-propagation.sh` — record crossing the mesh, machine to machine

```sh
harness/mesh-propagation.sh --publish [--keep SECONDS]
harness/mesh-propagation.sh --resolve <z32> [--key <hex>] [--pub-geo LAT,LNG]
```

`--publish` (machine A): mint an identity, sign a fresh `station_endpoint`, `put_record` it into the live DHT, print the z32 + storage key + the exact `--resolve` command to run on machine B. `--keep N` re-puts it every 60 s and holds N s (extends the ~5-min TTL window); default: publish once and exit.

`--resolve <z32>` (machine B): derive the storage key from the z32 (`sha256("station_endpoint" ‖ pubkey)`), poll `find_record` until it lands, then report time-to-resolve (from pool-up to found), retry count, whether the record's key matches the z32 (the propagation proof), `macula_record:verify` result, the advertised v6, and — with `--pub-geo` (printed by `--publish`) + `HECATE_GEO_*` set here — the great-circle distance between the two vantage points.

> A cross-station replica can come back with a non-canonical payload encoding, so `macula_record:verify` intermittently returns `signature_invalid` even though the record's key matches the published z32 — reported as a quirk, not a hard failure (the key-match is what proves it crossed).

---

## `demo.sh` — narrated walk-through

```sh
harness/demo.sh [--fast] [--keep SECONDS]
```

Five paced steps with ANSI styling: (1) connect to the live station fleet (who, how far) → (2) mint a fresh station identity (pubkey → MRI → DNS name) → (3) publish its endpoint into the mesh DHT → (4) ask the mesh to resolve it back (Tier-1, with trust verification) → (5) ask for it over ordinary DNS (`nslookup <z32>._st.macula.io` against the daemon's listener, output shown inline). `--fast` skips the pauses; `--keep N` leaves the listener up at the end. Good for a screencast.

---

## Caveats

- Needs IPv6 connectivity to the station fleet (`station-be-*.macula.io` are v6-only). ICMP to those hosts is occasionally lossy — a "ping unreachable" in `mesh-weather`/the harness's stations table is usually a momentary blip, not a real outage; the QUIC-level checks are the source of truth.
- The cross-station DHT find is documented to flake ~60% per attempt; the scripts retry, so a transient flake shouldn't fail a run — but a persistently broken mesh will.
- They resolve a **station** MRI (`mri:station:<z32>` ↔ `<z32>._st.macula.io`) — self-rooted, no realm trust chain. A `user`/`app`/`service` MRI through the realm chain is blocked on the leaf-storage-key gap; a `proc` MRI is resolvable but needs a provisioned realm (`realm_directory` + endorsements) these scripts don't set up.
- "Running on beam00" means `scp`ing a script there (the beam daemons run in docker, a different namespace) — or querying a running daemon's `/api/mesh/...` endpoints, which already have `macula_relay_discovery` populated. A daemon-API-backed `mesh-weather` would show the full fleet w/ geo-distances; not built yet.
```
