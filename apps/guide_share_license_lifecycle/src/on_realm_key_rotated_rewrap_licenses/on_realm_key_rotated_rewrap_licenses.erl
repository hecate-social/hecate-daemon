%%% @doc Process manager: `realm_shared_key_stored_v1` ->
%%% `rewrap_license_v1` for every realm-scope license this daemon
%%% issued under the previous `k_realm_version`.
%%%
%%% ## Trigger
%%%
%%% Subscribes to LOCAL `realm_shared_key_stored_v1` events on
%%% `realm_memberships_store`. A mesh `{realm}.keys.rotated` FACT
%%% received by this daemon produces a corresponding local store event
%%% via `realm_key_fetcher` / `store_realm_shared_key`. We react to the
%%% local event (not the mesh FACT directly) so we're sure the new
%%% K_realm is persisted and unsealable via `hecate_realm_crypto`.
%%%
%%% ## Race with the projection
%%%
%%% Both this PM and the `realm_shared_keys` ETS projection subscribe
%%% to the same event. Handler ordering is not guaranteed, so we can't
%%% assume the projection has advanced to `NewVersion` when we fire.
%%% To sidestep the race entirely we call
%%% `hecate_realm_crypto:wrap_with_sealed/2` with the event's own
%%% `k_realm_encrypted` bytes — no projection lookup needed.
%%%
%%% ## What we rewrap
%%%
%%% Query `project_share_licenses_store:list_active_for_realm_version/2`
%%% for `{Realm, NewVersion - 1}`. The projection already filters to
%%% realm-scope licenses (wrap_strategy = realm_key_v1). DID-scope
%%% licenses don't rotate — their CEKs ride on the grantee's X25519
%%% key which is unaffected by K_realm changes.
%%%
%%% ## Batch semantics
%%%
%%% One `batch_id` per rotation per issuer. All rewraps in a single
%%% rotation share the id; `licenses_rewrapped_batch_emitter` coalesces
%%% them into one `{realm}.licenses.rewrapped_batch` FACT.
%%% @end
-module(on_realm_key_rotated_rewrap_licenses).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

%% Testability seams — override via config for unit tests.
-export([default_config/0]).

interested_in() -> [<<"realm_shared_key_stored_v1">>].

init(Config) ->
    {ok, maps:merge(default_config(), Config)}.

default_config() ->
    #{%% Projection lookup
      list_fn     => fun project_share_licenses_store:list_active_for_realm_version/2,
      %% Crypto seams — PM works directly with event bytes
      unseal_fn   => fun hecate_crypto:decrypt/1,
      rewrap_fn   => fun hecate_realm_crypto:wrap_with_sealed/2,
      %% Command dispatcher (override in tests to capture dispatches)
      dispatch_fn => fun maybe_rewrap_license:dispatch/1,
      %% UUID generator
      uuid_fn     => fun default_uuid/0}.

handle_event(<<"realm_shared_key_stored_v1">>, Event, _Metadata, State) ->
    Data = extract_data(Event),
    _ = handle_rotation(Data, State),
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.

%%====================================================================
%% Internal
%%====================================================================

handle_rotation(Data, Config) ->
    Realm      = gf(realm, Data),
    NewVersion = gf(k_realm_version, Data),
    Sealed     = gf(k_realm_encrypted, Data),
    case rotation_ready(Realm, NewVersion, Sealed) of
        ok ->
            OldVersion = NewVersion - 1,
            rewrap_old_version(Realm, OldVersion, NewVersion, Sealed, Config);
        {skip, Reason} ->
            logger:debug("[on_realm_key_rotated] skipping rotation: ~p", [Reason])
    end.

rotation_ready(Realm, NewVersion, Sealed) ->
    case {Realm, NewVersion, Sealed} of
        {undefined, _, _} -> {skip, missing_realm};
        {_, undefined, _} -> {skip, missing_version};
        {_, _, undefined} -> {skip, missing_sealed_key};
        {_, V, _} when not is_integer(V) -> {skip, {bad_version, V}};
        {_, V, _} when V =< 1 -> {skip, {no_previous_version, V}};
        _                -> ok
    end.

rewrap_old_version(Realm, OldVersion, NewVersion, Sealed, Config) ->
    ListFn = maps:get(list_fn, Config),
    case ListFn(Realm, OldVersion) of
        {ok, []} ->
            logger:debug("[on_realm_key_rotated] no licenses to rewrap realm=~s v=~b",
                         [Realm, OldVersion]),
            ok;
        {ok, Entries} ->
            BatchId = (maps:get(uuid_fn, Config))(),
            logger:info("[on_realm_key_rotated] rewrapping realm=~s old=~b new=~b count=~b batch=~s",
                        [Realm, OldVersion, NewVersion, length(Entries), BatchId]),
            lists:foreach(
                fun(Entry) ->
                    rewrap_one(Entry, NewVersion, Sealed, BatchId, Config)
                end,
                Entries),
            ok;
        {error, Reason} ->
            logger:warning("[on_realm_key_rotated] list_fn failed realm=~s: ~p",
                           [Realm, Reason])
    end.

rewrap_one(#{license_id := LicenseId,
             origin_cek_sealed := OriginSealed} = _Entry,
           NewVersion, RealmSealed, BatchId, Config)
  when is_binary(OriginSealed) ->
    UnsealFn = maps:get(unseal_fn, Config),
    RewrapFn = maps:get(rewrap_fn, Config),
    DispatchFn = maps:get(dispatch_fn, Config),
    with_plaintext_cek(UnsealFn, OriginSealed, LicenseId,
        fun(PlaintextCek) ->
            do_rewrap(RewrapFn, RealmSealed, PlaintextCek,
                      LicenseId, NewVersion, BatchId, DispatchFn)
        end);
rewrap_one(#{license_id := LicenseId} = Entry, _NewVersion, _Sealed, _Batch, _Cfg) ->
    logger:warning("[on_realm_key_rotated] skipping license=~s: no origin_cek_sealed (~p)",
                   [LicenseId, Entry]).

with_plaintext_cek(UnsealFn, OriginSealed, LicenseId, Continuation) ->
    case UnsealFn(OriginSealed) of
        {ok, PlaintextCek} ->
            Continuation(PlaintextCek);
        {error, Reason} ->
            logger:warning("[on_realm_key_rotated] unseal failed license=~s: ~p",
                           [LicenseId, Reason])
    end.

do_rewrap(RewrapFn, RealmSealed, PlaintextCek, LicenseId, NewVersion, BatchId, DispatchFn) ->
    case RewrapFn(RealmSealed, PlaintextCek) of
        {ok, NewWrappedCek} ->
            dispatch_rewrap(DispatchFn, LicenseId, NewWrappedCek, NewVersion, BatchId);
        {error, Reason} ->
            logger:warning("[on_realm_key_rotated] rewrap failed license=~s: ~p",
                           [LicenseId, Reason])
    end.

dispatch_rewrap(DispatchFn, LicenseId, NewWrappedCek, NewVersion, BatchId) ->
    case rewrap_license_v1:new(#{
            license_id          => LicenseId,
            new_wrapped_cek     => NewWrappedCek,
            new_k_realm_version => NewVersion,
            batch_id            => BatchId}) of
        {ok, Cmd} ->
            log_dispatch_result(LicenseId, DispatchFn(Cmd));
        {error, Reason} ->
            logger:warning("[on_realm_key_rotated] cmd build failed license=~s: ~p",
                           [LicenseId, Reason])
    end.

log_dispatch_result(LicenseId, {ok, _V, _Events}) ->
    logger:debug("[on_realm_key_rotated] rewrap dispatched license=~s", [LicenseId]);
log_dispatch_result(LicenseId, {error, stale_rewrap}) ->
    logger:debug("[on_realm_key_rotated] rewrap stale (already at newer version) license=~s",
                 [LicenseId]);
log_dispatch_result(LicenseId, {error, Reason}) ->
    logger:info("[on_realm_key_rotated] rewrap dispatch error license=~s: ~p",
                [LicenseId, Reason]).

%%====================================================================
%% Helpers
%%====================================================================

extract_data(#{data := D}) when is_map(D) -> D;
extract_data(E) when is_map(E) -> E;
extract_data(_) -> #{}.

gf(K, M) -> gf(K, M, undefined).
gf(K, M, Default) when is_map(M) ->
    case maps:find(K, M) of
        {ok, V} -> V;
        error ->
            case is_atom(K) of
                true  -> maps:get(atom_to_binary(K, utf8), M, Default);
                false -> Default
            end
    end;
gf(_, _, Default) -> Default.

default_uuid() ->
    Bytes = crypto:strong_rand_bytes(16),
    binary:encode_hex(Bytes, lowercase).
