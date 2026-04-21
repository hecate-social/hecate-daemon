%%% @doc Process Manager: realm_membership_confirmed_v1 → fetch K_realm.
%%%
%%% On realm confirmation, calls `io.macula.realm.get_shared_key` over
%%% the mesh, re-seals the returned plaintext with `hecate_crypto`, and
%%% dispatches `store_realm_shared_key_v1` against the membership
%%% aggregate.
%%%
%%% Failure modes are logged only — a missing K_realm leaves the
%%% membership confirmed-but-key-less, which the UI surfaces via the
%%% status bit flags. A later boot-time catch-up (future work) retries.
%%% @end
-module(on_realm_membership_confirmed_fetch_key).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

-define(RPC_PROCEDURE, <<"io.macula.realm.get_shared_key">>).
-define(RPC_TIMEOUT,   10000).

interested_in() -> [<<"realm_membership_confirmed_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    MembershipId = gf(membership_id, Data),
    Realm = resolve_realm(Data),
    fetch_and_store(MembershipId, Realm),
    {ok, State}.

%% ===================================================================
%% Internal
%% ===================================================================

%% Confirmed events today carry realm_id as the URI string ("io.macula")
%% per hecate-daemon's membership convention. Fall back to realm_url
%% host if realm_id is missing.
resolve_realm(Data) ->
    case gf(realm_id, Data) of
        undefined -> gf(realm_url, Data);
        Realm     -> Realm
    end.

fetch_and_store(undefined, _Realm) ->
    logger:warning("[pm.fetch_key] missing membership_id, skipping");
fetch_and_store(_MId, undefined) ->
    logger:warning("[pm.fetch_key] missing realm, skipping");
fetch_and_store(MembershipId, Realm) ->
    case hecate_mesh:call(?RPC_PROCEDURE, #{realm => Realm}, ?RPC_TIMEOUT) of
        {ok, #{<<"version">> := V, <<"key_b64">> := KeyB64}} ->
            store_from_b64(MembershipId, Realm, V, KeyB64);
        {ok, #{version := V, key_b64 := KeyB64}} ->
            store_from_b64(MembershipId, Realm, V, KeyB64);
        {ok, Other} ->
            logger:warning("[pm.fetch_key] unexpected response shape: ~p", [Other]);
        {error, Reason} ->
            logger:warning("[pm.fetch_key] RPC failed for ~s: ~p", [Realm, Reason])
    end.

store_from_b64(MembershipId, Realm, Version, KeyB64) ->
    %% If base64 is malformed the realm server has returned garbage —
    %% let this handler crash and rely on supervisor restart + future
    %% retries. A bad key is a contract violation, not a recoverable
    %% state.
    Plaintext = base64:decode(KeyB64),
    {ok, Sealed} = hecate_crypto:encrypt(Plaintext),
    dispatch_store(MembershipId, Realm, Version, Sealed).

dispatch_store(MembershipId, Realm, Version, Sealed) ->
    case store_realm_shared_key_v1:new(#{
        membership_id     => MembershipId,
        realm             => as_binary(Realm),
        k_realm_version   => Version,
        k_realm_encrypted => Sealed
    }) of
        {ok, Cmd} ->
            case maybe_store_realm_shared_key:dispatch(Cmd) of
                {ok, _V, _Events} ->
                    logger:info("[pm.fetch_key] K_realm v~p stored for ~s",
                                [Version, Realm]);
                {error, Reason} ->
                    logger:warning("[pm.fetch_key] dispatch failed for ~s: ~p",
                                   [Realm, Reason])
            end;
        {error, Reason} ->
            logger:warning("[pm.fetch_key] command build failed for ~s: ~p",
                           [Realm, Reason])
    end.

as_binary(B) when is_binary(B) -> B;
as_binary(L) when is_list(L)   -> list_to_binary(L);
as_binary(A) when is_atom(A)   -> atom_to_binary(A, utf8).

gf(Key, Data) when is_map(Data) ->
    maps:get(Key, Data, maps:get(atom_to_binary(Key, utf8), Data, undefined));
gf(_Key, _Data) ->
    undefined.
