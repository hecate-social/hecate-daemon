%%% @doc Projection: realm_shared_key_stored_v1 -> realm_shared_keys ETS.
%%%
%%% Keyed by realm URI. Monotonic version guard — a replayed or
%%% late-arriving event never overwrites a newer one.
%%% @end
-module(realm_shared_key_stored_v1_to_realm_shared_keys).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, realm_shared_keys).

interested_in() ->
    [<<"realm_shared_key_stored_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = _Event, _Metadata, State, RM) ->
    Realm     = gf(realm, Data),
    NewVer    = gf(k_realm_version, Data),
    Encrypted = gf(k_realm_encrypted, Data),
    AtMs      = gf(received_at, Data),
    MId       = gf(membership_id, Data),
    maybe_put(Realm, NewVer, Encrypted, AtMs, MId, State, RM).

%% ===================================================================
%% Internal
%% ===================================================================

maybe_put(Realm, Ver, Enc, At, MId, State, RM)
  when is_binary(Realm), is_integer(Ver), Ver > 0, is_binary(Enc) ->
    case current_version(Realm) of
        Current when is_integer(Current), Current >= Ver ->
            %% stale or replay — keep the newer one
            {ok, State, RM};
        _ ->
            Entry = #{
                realm             => Realm,
                k_realm_version   => Ver,
                k_realm_encrypted => Enc,
                received_at       => At,
                membership_id     => MId
            },
            {ok, RM2} = evoq_read_model:put(Realm, Entry, RM),
            {ok, State, RM2}
    end;
maybe_put(_Realm, _Ver, _Enc, _At, _MId, State, RM) ->
    {ok, State, RM}.

current_version(Realm) ->
    case ets:lookup(?TABLE, Realm) of
        [{_, #{k_realm_version := V}}] -> V;
        []                              -> 0
    end.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
