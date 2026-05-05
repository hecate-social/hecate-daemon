# PLAN — daemon + stub V1 → V2 SDK migration

**Status:** Stage 1 draft — research only, no code changes yet
**Date:** 2026-05-05
**Drives:** macula 3.16 SDK additions (whatever this plan surfaces as gaps)

---

## tl;dr

Both `hecate-daemon` and `hecate-stub` already pin macula `~> 3.15.0`, but the actual call sites are a mosaic:

| Layer | Daemon current | Stub current | Status |
|---|---|---|---|
| DHT (`put_record` / `find_record` / `find_records_by_type`) | `macula_station_link` (V2) | `macula_station_link` (V2) | done |
| Probe / announcer wiring | `macula:` facade (V2) | n/a | done |
| Pubsub | `macula_multi_relay` (V1) | `macula_mesh_client` (V1) | **migrate** |
| RPC (call / advertise / call_stream / advertise_stream) | `macula_multi_relay` (V1) | `macula_mesh_client` (V1) | **migrate** |
| Status / introspection | `macula_multi_relay:get_status/1` (V1) | none | **migrate + SDK gap** |

The migration is therefore **incremental**, not a rewrite. The remaining V1 surface in the daemon is concentrated in a single 926-line module (`hecate_mesh_client.erl`); the stub has three files using the V1 mesh_client.

The handover's claim that the daemon was on macula `~> 3.7` was outdated — actual pin has been advancing through 3.7 → 3.8 → 3.9 → 3.10 → 3.11 → 3.12 → 3.15 over the last quarter, with each step migrating one slice. This plan finishes the job.

---

## Section 1 — Current state, with line refs

### 1.1 Daemon: `apps/hecate_mesh/src/hecate_mesh_client.erl`

A 926-line gen_server that owns ONE `macula_multi_relay` pid (call it `Client`) plus a pool of `macula_station_link` workers (`station_clients` map). Two parallel paths:

| Surface | Backed by | Lines |
|---|---|---|
| `publish/2`, `subscribe/2`, `unsubscribe/1` | `macula_multi_relay:publish/3`, `subscribe/3`, `unsubscribe/2` | 322-394 |
| `advertise/2`, `register_stream_advertisement/3` | `macula_multi_relay:advertise/3`, `advertise_stream/4` | 401-469 |
| `call/3,4`, `call_stream/4` | `macula_multi_relay:call/4`, `call_stream/4` | 411-428 |
| `get_status/0` | `macula_multi_relay:get_status/1` | 303-318, 829-832 |
| `put_record/1`, `find_record/1`, `find_records_by_type/1` | `macula_station_link:put_record/3`, `find_record/3`, `find_records_by_type/3` (already V2) | 345-380 |
| `connected_peer_pubkeys/0` | `macula_station_link:peer_node_id/1` (V2) | 337-344, 759 |

The dual-stack is intentional: pubsub/RPC stayed on V1 because the V1 facade already had the multi-relay-fan-out semantics that V2 surfaces are now providing via `macula_client` pool + `macula_pubsub`. No SDK gap blocks the migration today.

### 1.2 Stub: `src/hecate_stub_*.erl`

Already partially migrated:

| File | Uses | Status |
|---|---|---|
| `hecate_stub_daemon.erl` | `macula_station_link:start_link/1`, `put_record/2,3`, `peer_node_id/1`, `stop/1` | V2, done |
| `hecate_stub_weather.erl` | `macula_mesh_client:publish/3`, `call/4` | **V1, migrate** |
| `hecate_stub_probe.erl` | `macula_mesh_client:subscribe/3`, `publish/3` | **V1, migrate** |
| `hecate_stub_mesh.erl` | references both V1 and V2 (`macula_station_link` URL parsing) | inspect |
| `hecate_stub_dist.erl`, `hecate_stub_health.erl`, `hecate_stub_probe.erl` | unclear without further read | inspect |

### 1.3 V2 SDK surface available today (macula 3.15.x)

From `~/work/codeberg.org/macula-io/macula/src/macula.erl`:

| Op | V2 facade |
|---|---|
| Connect | `macula:connect(Seeds, Opts)` → pool pid |
| Disconnect / close | `macula:close/1`, `disconnect/1` |
| Publish | `macula:publish/3,4,5` — realm-aware overloads |
| Subscribe | `macula:subscribe/3,4,5` |
| RPC call | `macula:call/3,4` |
| RPC advertise | `macula:advertise/3,4`, `unadvertise/2` |
| Streaming RPC | `macula:call_stream/2,3,4`, `advertise_stream/2,3,4` |
| DHT writes | `macula:put_record/2`, `find_record/2`, `find_records_by_type/2,3` |
| Erlang dist | `macula:call_node/4,5`, `resolve/2`, `list_nodes/1,2` |
| Streams (low-level) | `macula:recv/1,2`, `send/2,3`, `abort/3`, `close_stream/1` |
| Node identity / peers | `macula:get_node_id/1`, `get_known_peers/1` |

---

## Section 2 — V1 → V2 mapping

### 2.1 Daemon mapping (multi_relay → macula facade)

| V1 call | V2 equivalent | Notes |
|---|---|---|
| `macula_multi_relay:start_link(#{relays, realm, identity, site, connections})` | `macula:connect(Seeds, Opts)` | `Seeds` = list of relay URLs; `Opts` = `#{realm, identity, ...}`. Need to verify `site` / `connections` opts surface. |
| `macula_multi_relay:publish(Client, Topic, Payload)` | `macula:publish(Pool, Realm, Topic, Payload)` | Realm becomes explicit. Daemon already knows its realm in `state.realm`. |
| `macula_multi_relay:subscribe(Client, Topic, Callback)` | `macula:subscribe(Pool, Realm, Topic, Subscriber)` | Subscriber is a pid that receives `{macula_event, Sub, Topic, Payload, Meta}` — different from V1's callback function shape. **Daemon must rewire callbacks → message receivers**, OR the subscriber pid forwards back to a callback dispatcher. |
| `macula_multi_relay:unsubscribe(Client, SubRef)` | `macula:unsubscribe(Pool, Sub)` | direct |
| `macula_multi_relay:advertise(Client, Procedure, Handler)` | `macula:advertise(Pool, Procedure, Handler)` | direct |
| `macula_multi_relay:advertise_stream(Client, Procedure, Mode, Handler)` | `macula:advertise_stream(Pool, Procedure, Mode, Handler)` | direct |
| `macula_multi_relay:unadvertise(Client, Procedure)` | `macula:unadvertise(Pool, Procedure)` | direct |
| `macula_multi_relay:call(Client, Procedure, Args, Timeout)` | `macula:call(Pool, Procedure, Args, Timeout)` | direct |
| `macula_multi_relay:call_stream(Client, Procedure, Args, Timeout)` | `macula:call_stream(Pool, Procedure, Args, Opts)` | Opts shape change — verify timeout encoding. |
| `macula_multi_relay:get_status(Client)` | **NO direct equivalent** | See SDK gap §3.1. Workaround: build status from `list_nodes/1` + per-link introspection. |
| `macula_multi_relay:stop(Client)` | `macula:close(Pool)` | direct |

### 2.2 Stub mapping (mesh_client → macula facade)

`macula_mesh_client` is the lighter single-relay V1 client. Mapping:

| V1 call | V2 equivalent |
|---|---|
| `macula_mesh_client:start(...)` (spawn shape unclear without read) | `macula:connect([SeedUrl], #{realm, identity})` |
| `macula_mesh_client:publish(Pid, Topic, Payload)` | `macula:publish(Pool, Realm, Topic, Payload)` |
| `macula_mesh_client:subscribe(Pid, Topic, Callback)` | `macula:subscribe(Pool, Realm, Topic, Subscriber)` |
| `macula_mesh_client:call(Pid, Proc, Args, Timeout)` | `macula:call(Pool, Proc, Args, Timeout)` |

The callback-vs-subscriber-pid shape change applies here too.

---

## Section 3 — SDK gaps surfaced by the mapping

This is the daemon-driving-the-SDK list. Each gap is a candidate for macula 3.16.0.

### 3.0 GAP — pool-aware non-streaming RPC

**V2 today** has `macula_client` (pool) for pubsub only and `macula_station_link` (per-station) for everything else including RPC. There's no `macula:call(Pool, Realm, Procedure, Args, Timeout)` that fans out across a pool's links automatically.

**Daemon behaviour** today: hand-rolls the fan-out via `dht_via_stations/2` (`hecate_mesh_client.erl:806-823`). Phase A reuses the same shape for RPC.

**Proposed SDK addition (3.16.0):**
```erlang
-spec macula:call(pool(), realm(), procedure(), term(), pos_integer()) ->
    {ok, term()} | {error, term()}.
-spec macula:advertise(pool(), realm(), procedure(), handler()) ->
    ok | {error, term()}.
-spec macula:unadvertise(pool(), realm(), procedure()) -> ok.
```

Internal: pool picks first connected station (advertise fans out to all). Resolves the daemon's hand-rolled `via_any_station/2` and `via_all_stations/2` helpers into one place.

### 3.1 GAP — pool-aware streaming RPC

**V2 today** routes streaming RPC through `macula_mesh_client` (V1) or local-only `macula_stream_local`. `macula_station_link` has NO stream variants. So `macula:call_stream(Client, Procedure, Args)` falls through to V1 mesh_client.

**Daemon needs** streaming RPC for git fetch (`relay_git_rpc_api`) and inproc paths (`hecate_mesh_inproc.erl`). Currently uses V1 multi_relay.

**Proposed SDK addition (3.16.0):**
```erlang
-spec macula_station_link:call_stream(pid(), <<_:256>>, binary(), term(), map()) ->
    {ok, stream()} | {error, term()}.
-spec macula_station_link:advertise_stream(pid(), <<_:256>>, binary(),
                                            stream_mode(), stream_handler()) ->
    ok | {error, term()}.
-spec macula_station_link:unadvertise_stream(pid(), <<_:256>>, binary()) -> ok.
%% + pool-level wrappers in macula:
-spec macula:call_stream(pool(), realm(), procedure(), term(), map()) ->
    {ok, stream()} | {error, term()}.
-spec macula:advertise_stream(pool(), realm(), procedure(), stream_mode(),
                               stream_handler()) -> ok | {error, term()}.
```

### 3.2 GAP — pool status / introspection

**V1 had** `macula_multi_relay:get_status/1 -> {ok, #{relays, connections, …}}` returning a map summarising health per relay.

**V2 today** exposes `macula:list_nodes(Pool)` (returns peer node IDs) and per-link `macula_station_link:peer_node_id/1` / `is_connected/1`. There's no single roll-up of "for this pool, which seeds are healthy, which are draining, what's the dedup-window depth, etc."

**Daemon needs** something like `get_status` because the web UI surfaces it (`POST /api/mesh/activate` shows status). Today daemon code at line 829-832 calls V1 `get_status`. The daemon CAN reconstruct status from `list_nodes` + per-link introspection but that's fragile (knows pool internals).

**Proposed SDK addition (3.16.0):**
```erlang
-spec macula:status(pool()) -> {ok, status()}.
-type status() :: #{
    seeds              := [seed()],
    healthy_links      := non_neg_integer(),
    failed_links       := non_neg_integer(),
    realm              := binary(),
    self_node_id       := macula_identity:pubkey() | undefined,
    pending_subs       := non_neg_integer(),
    pending_advs       := non_neg_integer()
}.
```

Single-call summary the daemon can drop straight onto `/api/mesh/activate`.

### 3.3 GAP — subscribe-with-callback shim

**V1** subscribers passed a callback `fun((Topic, Payload) -> any())`.

**V2** subscribers receive messages — `{macula_event, Sub, Topic, Payload, Meta}` — which forces a gen_server / receive-loop on the consumer side.

The daemon's current code dispatches to many ad-hoc callbacks (some sync, some spawning workers). Migrating all of them to `receive` blocks is invasive. **A small SDK helper** that wraps callback semantics on top of the message-based API would shrink the daemon migration considerably:

```erlang
-spec macula:subscribe_callback(pool(), realm(), topic(),
                                fun((topic(), payload(), meta()) -> any())) ->
    {ok, sub()} | {error, term()}.
```

Internally spawns a tiny receiver that invokes the fun and traps crashes.

**Trade-off:** this is a convenience shim that some would say belongs in the consumer, not the SDK. Reasonable counter: the daemon AND the stub AND any future consumer will want it; better to have one well-tested implementation in the SDK than three subtly-different copies.

**Decision:** propose for 3.16.0, leave easy to remove if you'd rather keep the SDK message-based-only.

### 3.4 GAP — `connect/2` opts surface

V1's `macula_multi_relay:start_link` took `#{relays, realm, identity, site, connections}`. V2's `macula:connect(Seeds, Opts)` accepts a less-documented `Opts` map. Need to verify what's accepted; `site` and `connections` (from V1) may have no V2 equivalent or different names.

**Action:** read `macula_client:connect/2` thoroughly during Stage 2; if any V1 opt has no V2 equivalent and is in active use, surface as 3.16 gap.

### 3.5 GAP — pool dedup config exposure

V1 had implicit dedup. V2's `macula_client` doc references `dedup_window_ms` / `dedup_sweep_ms`. Verify these are caller-tunable; if not, expose for callers that need different windows (e.g. weather-publishing stub vs. realm-control daemon).

### 3.6 NON-GAPS (worth flagging as deliberate)

- **realm-per-call vs per-pool** — V2 takes realm on each publish/subscribe call. V1 took it once at start_link. This is an INTENTIONAL improvement (multi-realm per pool), not a gap. Daemon's `state.realm` becomes a default that's passed in on each call.
- **`connected_peer_pubkeys`** — already-V2 in the daemon (line 337-344), just calls `macula_station_link:peer_node_id/1` over the local pool. No change needed.

---

## Section 4 — Migration sequencing

Each step is a self-contained commit with tests + smoke validation against the live BE fleet.

### Phase A — daemon RPC surface

#### A1 (non-streaming RPC, lands on current SDK 3.15.x)

1. Reuse the existing `station_clients` pool for RPC. Generalise `dht_via_stations/2` into:
   - `via_any_station/2` — first-connected, first-success (for `call`)
   - `via_all_stations/2` — fan-out to all, accept partial success (for `advertise`/`unadvertise`)
2. Replace `macula_multi_relay:advertise/3` calls with `macula_station_link:advertise/4` via `via_all_stations`.
3. Replace `macula_multi_relay:call/4` calls with `macula_station_link:call/5` via `via_any_station`.
4. Replace `macula_multi_relay:unadvertise/2` similarly.
5. Migrate `drain_pending` advertise replays to V2.

Validation: `serve_git_over_mesh` non-streaming integration tests; daemon CT.

#### A2 (streaming RPC, lands on SDK 3.16.0 — blocked on §3.1 gap)

6. Replace `macula_multi_relay:call_stream/4` with `macula_station_link:call_stream/5` (3.16).
7. Replace `macula_multi_relay:advertise_stream/4` with `macula_station_link:advertise_stream/5` (3.16).

Validation: live `git clone` / `git fetch` over mesh to a daemon.

### Phase B — daemon pubsub surface

5. **Subscribe shim decision** — either land §3.2 in SDK 3.16 first, or write a daemon-internal shim. If SDK first, this phase blocks on SDK release.
6. **Switch publish/subscribe** to `macula:publish/4` / `macula:subscribe/4`.
7. **Replace `pending_subs` queue** semantics — V2's pool has its own buffering, daemon may not need its own queue anymore.

Validation: `MESH_INTEGRATION.md` smoke (mesh_proof_coordinator probes).

### Phase C — daemon status surface

8. **Land §3.1 in SDK 3.16** (or workaround in daemon if SDK not ready).
9. **Switch `get_status/0` to `macula:status/1`**.
10. **Delete the multi_relay client + the dual-stack** in `hecate_mesh_client.erl`. Module shrinks substantially.

Validation: `/api/mesh/activate` returns the expected shape.

### Phase D — stub migration

11. **`hecate_stub_weather.erl`** — switch to `macula:publish/4` and `macula:call/4`.
12. **`hecate_stub_probe.erl`** — switch to `macula:subscribe/4` (uses the §3.2 shim or message-based API).
13. **`hecate_stub_mesh.erl`** — full read pass; migrate any remaining V1 calls.

Validation: stub instances on beam00–03 + linode-stockholm/milan publish weather facts and the realm consumes them.

### Phase E — SDK 3.16 + cleanup

14. **macula 3.16.0 release** — bundles §3.1 (`status/1`), §3.2 (`subscribe_callback/4`), and any §3.3–§3.4 that landed.
15. **Bump daemon + stub deps to `~> 3.16.0`**.
16. **Re-validate fleet smoke + run full daemon CT suite**.
17. **Update both repos' rebar.config comment trail** with the migration milestone.

---

## Section 5 — Validation strategy

| Stage | What to test | Where |
|---|---|---|
| Each phase commit | `rebar3 ct`, `rebar3 dialyzer` | local |
| Phase B finished | mesh proof ceremony succeeds | local + dev VM |
| Phase C finished | `/api/mesh/activate` returns valid shape | local daemon |
| Phase D finished | stub on beam00 publishes weather, brussels station receives | live |
| Phase E finished | full smoke suite (`smoke-station.sh` × 7 stations, plus daemon health) | live |

Rollback strategy: each phase is a separate commit; revert if a phase regresses. The dual-stack period (Phase A step 1 → A step 2) keeps the V1 path live while V2 is verified, eliminating big-bang risk.

---

## Section 6 — Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| V2 callback semantics differ subtly from V1 | high | Add §3.2 shim, run dual-stack in Phase A |
| `macula:connect` opts surface missing V1 fields | medium | §3.3 audit during Phase A; surface as SDK gap if real |
| `mesh_proof_coordinator` integration breaks under V2 | medium | Phase B includes proof ceremony validation; phase B can be split into sub-steps |
| Stub fleet across multiple boxes doesn't restart cleanly | low | Per-box rolling deploy; smoke test catches breakage |
| SDK 3.16 release blocks migration | medium | Phase E final cleanup waits for SDK; Phases A–D land on existing 3.15.x |

---

## Section 7 — Open questions

1. **Subscribe-callback shim (§3.2)** — accept this as SDK addition, or daemon-internal helper?
2. **Status shape (§3.1)** — anything beyond the proposed fields the daemon's web UI needs?
3. **`macula_station_link` deprecation timing** — once daemon goes pool-only, the bare-station-link surface only matters for stub-style direct dialing. Mark as advanced API or deprecate?
4. **CT environment for Phase A–C** — does daemon CT spin up real macula-stations, or use mocks? If mocks, do they cover the V2 wire shape?
5. **Stub multi-box deploy** — is there a deploy-stub.sh per box, or do we drive the rollout from `macula-demo/scripts/`?

---

## Section 8 — Stage gate before code

Before Stage 2 (execution) begins, confirm:

- [ ] §3.1 status surface — sketch SDK API, get nod
- [ ] §3.2 subscribe-callback shim — yes / no for SDK
- [ ] Phase ordering A→D — agreed?
- [ ] Validation environment — do we have beam00–03 stubs + a live daemon to point at the BE fleet?
