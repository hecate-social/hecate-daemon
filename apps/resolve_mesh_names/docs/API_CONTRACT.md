# API contract — `resolve_mesh_names_api`

The single public surface of `resolve_mesh_names` (`src/library_api/resolve_mesh_names_api.erl`).
Every consumer — the Tier-2 wire bridges (`serve_dns_over_mesh`, future
`serve_https_over_mesh`/…), the daemon REST API, the TUI naming browser — imports
from this module and nothing else. Canonical contract: `PLAN_RESOLVE_MESH_NAMES_PART1`
§3 (+ §0 for the divergences below).

Every call takes the macula V2 pool (`macula:pool()`, a pid) as its first
argument. No qnames, no RRsets, no TTLs (push-driven primary; TTL is a fallback),
no rcodes — clean Erlang `{ok, _} | {error, atom() | tuple()}`.

```erlang
%% Single-shot resolve: MRI → verified leaf record(s).
-spec resolve(pool(), mri())        -> {ok, [verified_record()]} | {error, _}.
-spec resolve(pool(), mri(), map()) -> {ok, [verified_record()]} | {error, _}.
%%   Opts: find_fn (DI for tests, default macula:find_record/2),
%%         now_ms (clock override), max_attempts, grace_window_ms.

%% Force-refresh: drop the L5 cache entry for an MRI, then resolve again.
-spec refresh(pool(), mri())        -> {ok, [verified_record()]} | {error, _}.
-spec refresh(pool(), mri(), map()) -> {ok, [verified_record()]} | {error, _}.

%% Push subscription: deliver change notifications to Pid's mailbox as
%%   {resolve_mesh_names, sub_handle(), record_changed,    verified_record()}
%%   {resolve_mesh_names, sub_handle(), record_tombstoned, mri()}
%%   {resolve_mesh_names, sub_handle(), trust_chain_lost,  mri(), reason()}
-spec watch(pool(), mri(), pid())    -> {ok, sub_handle()} | {error, _}.
-spec unwatch(sub_handle())          -> ok.   %% idempotent

%% Composite query: records + endorsements + backlinks + consensus + last_modified
%% in one call, with a `partial => true' flag when a sub-query fails.
-spec describe(pool(), mri())        -> {ok, description()} | {error, _}.
-spec describe(pool(), mri(), map()) -> {ok, description()} | {error, _}.

%% Walk the 5-link trust chain explicitly (resolve/2 uses this internally).
-spec verify_trust_chain(pool(), mri(), leaf_type()) -> {ok, verified_record()} | {error, _}.
-spec verify_trust_chain(pool(), mri(), LeafKey :: binary() | undefined, leaf_type(), map())
                                                     -> {ok, verified_record()} | {error, _}.

%% Reverse-direction query (who endorsed / delegated to this MRI).
-spec backlinks(pool(), mri())       -> {ok, [link()]} | {error, _}.
```

## `verified_record()` shape

What `resolve` / `verify_trust_chain` return (one element per resolved leaf):

```erlang
#{ record_type   => station_endpoint | procedure_advertisement | ...,
   mri           => binary(),
   payload       => map(),           %% the raw macula_record payload — see "payload key forms" below
   signer_pubkey => <<_:32/binary>>,
   chain         => [chain_step()],   %% [#{type => self_rooted | leaf, pubkey => _}]
   expires_at    => integer(),        %% ms epoch
   version       => binary() | undefined,
   observed_at   => integer() }
```

**Payload key forms** — `payload` is carried through as `macula_record:decode/1`
returned it, and that codec is non-deterministic about key form: it
`binary_to_existing_atom`s text-string keys (atom if the atom pre-exists in
loaded code, else `{text, <<"k">>}`), and scalar text values stay `{text, Bin}`-
wrapped while text values inside a list come back bare. **Read payload fields
tolerantly** — try atom ⊕ `{text, bin}` ⊕ bare-bin keys, unwrap `{text, V}`. The
DNS bridge does this via `serve_dns_over_mesh:synthesize_rr_set:payload_field/4`.
(Normalising the payload at this boundary is a future contract clean-up.)

## What's an honest stub today (per `PLAN..._PART1` §0)

- **`resolve` / `refresh`** resolve `mri:station:<z32>` (self-rooted) and
  `mri:proc:...` (realm chain). `user` / `app` / `service` / `device` MRIs →
  `{error, {not_resolvable_yet, Type}}` (no MRI→storage-key mapping yet — a
  macula 4.4.0 candidate).
- **`backlinks/2`** → `{error, backlinks_not_yet_implemented}` (the SDK's RME
  schema has no `path` field and there's no reverse index — needs that index, or
  a realm-scoped backlink record).
- **`describe`'s `endorsements`** → `[]` (the trust chain caches the member
  pubkey in L3, not the full RME — needs a fresh fetch); `consensus` →
  `#{replicas => 1, agreed => 1}` (real k-of-n quorum is a substrate feature);
  the `backlinks` sub-result is the error above, so `describe` flags `partial`.
- **`watch`** delivers current-value-on-subscribe (app env
  `watch_delivers_current_value`) and `realm_changed`-driven notifications;
  **station** MRIs aren't matched by `realm_changed` (self-rooted, no realm) — a
  station watcher gets current-value-on-subscribe only.
- Gated on macula 4.4.0 (`dane_pin` 0x15, `coverage_proof` 0x16): proper
  NXDOMAIN proofs (a missing endorsement → `{error, coverage_unknown}`) and TLSA
  verification (skipped).

Wire bridges translate this to their protocol shape at their own boundary; they
never hold naming, trust, or cache state.
