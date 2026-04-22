%%% @doc Shared fetch-seal-dispatch helper for `K_realm` delivery.
%%%
%%% Used by:
%%%   - `on_realm_membership_confirmed_fetch_key` (reacts to confirm events)
%%%   - `catch_up_realm_keys` (runs at boot + on an interval)
%%%
%%% The call path is:
%%%
%%%   1. `io.macula.realm.get_shared_key` mesh RPC returns plaintext
%%%      K_realm (base64).
%%%   2. Decoded bytes are re-sealed with `hecate_crypto:encrypt/1`
%%%      (daemon-local wrap, Erlang-cookie keyed).
%%%   3. `store_realm_shared_key_v1` command dispatched against the
%%%      membership aggregate — the aggregate's projection populates
%%%      `realm_shared_keys` ETS for `hecate_realm_crypto` consumers.
%%%
%%% Idempotent — the projection has a monotonic-version guard, so
%%% dispatching the same (or stale) version is harmless.
%%% @end
-module(realm_key_fetcher).

-export([fetch_and_store/2]).

-define(RPC_PROCEDURE, hecate_topics:realm_hope(<<"identity">>, <<"get_shared_key">>, 1)).
-define(RPC_TIMEOUT,   10000).

-type result() :: {ok, pos_integer()} | {error, term()}.

%% @doc Fetch K_realm for `Realm`, seal it, dispatch store command against
%% the given membership. Returns the stored version on success.
-spec fetch_and_store(binary(), binary()) -> result().
fetch_and_store(MembershipId, Realm)
  when is_binary(MembershipId), byte_size(MembershipId) > 0,
       is_binary(Realm),        byte_size(Realm) > 0 ->
    case call_mesh(Realm) of
        {ok, #{<<"version">> := V, <<"key_b64">> := KeyB64}} ->
            store_from_b64(MembershipId, Realm, V, KeyB64);
        {ok, #{version := V, key_b64 := KeyB64}} ->
            store_from_b64(MembershipId, Realm, V, KeyB64);
        {ok, Other} ->
            {error, {unexpected_rpc_shape, Other}};
        {error, _} = Err ->
            Err
    end;
fetch_and_store(_, _) ->
    {error, missing_fields}.

%%====================================================================
%% Internal
%%====================================================================

%% hecate_mesh_client may not be registered yet during event replay on
%% boot. Defensive whereis avoids :noproc crash loops.
call_mesh(Realm) ->
    case erlang:whereis(hecate_mesh_client) of
        undefined -> {error, mesh_not_ready};
        _Pid      -> hecate_mesh:call(?RPC_PROCEDURE, #{realm => Realm}, ?RPC_TIMEOUT)
    end.

store_from_b64(MembershipId, Realm, Version, KeyB64) ->
    Plaintext = base64:decode(KeyB64),
    {ok, Sealed} = hecate_crypto:encrypt(Plaintext),
    dispatch_store(MembershipId, Realm, Version, Sealed).

dispatch_store(MembershipId, Realm, Version, Sealed) ->
    case store_realm_shared_key_v1:new(#{
        membership_id     => MembershipId,
        realm             => Realm,
        k_realm_version   => Version,
        k_realm_encrypted => Sealed
    }) of
        {ok, Cmd} ->
            dispatch_command(Cmd, Version);
        {error, _} = Err ->
            Err
    end.

dispatch_command(Cmd, Version) ->
    case maybe_store_realm_shared_key:dispatch(Cmd) of
        {ok, _V, _Events} -> {ok, Version};
        {error, _} = Err  -> Err
    end.
