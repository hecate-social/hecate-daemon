%%% @doc Emitter: identity_public_key_announced_v1 domain event → mesh
%%% FACT on `{realm}.identity.public_key_announced`.
%%%
%%% Realm-server-side `project_realm_identities` app subscribes to this
%%% topic and populates the DID→pubkey directory used by
%%% `io.macula.realm.get_member_public_keys` RPC (DID-scope license
%%% issuance in Phase D).
%%%
%%% The `encryption_public_key` is base64-encoded on the wire for
%%% transport safety (mesh payloads are JSON-friendly maps).
%%% @end
-module(identity_public_key_announced_v1_to_mesh).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"identity_public_key_announced_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(<<"identity_public_key_announced_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    publish(Data),
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.

%%%===================================================================
%%% Internal
%%%===================================================================

publish(Data) ->
    Mri = gf(mri, Data),
    Pub = gf(encryption_public_key, Data),
    case {Mri, Pub} of
        {undefined, _} ->
            logger:warning("[announce_pubkey_emit] missing mri");
        {_, undefined} ->
            logger:warning("[announce_pubkey_emit] missing encryption_public_key");
        _ ->
            do_publish(Mri, Pub, Data)
    end.

do_publish(Mri, Pub, Data) ->
    Realm = realm_from_mri(Mri),
    Topic = hecate_topics:realm_fact(<<"identity">>, <<"public_key_announced">>, 1),
    Fact = #{
        mri                    => Mri,
        realm                  => Realm,
        encryption_public_key  => base64:encode(Pub),
        announced_at           => gf(announced_at, Data,
                                     erlang:system_time(millisecond))
    },
    case hecate_mesh:publish(Topic, Fact) of
        ok ->
            logger:info("[announce_pubkey_emit] ~s -> ~s", [Mri, Topic]);
        {error, Reason} ->
            logger:warning("[announce_pubkey_emit] publish failed ~s: ~p",
                           [Mri, Reason])
    end.

%% mri:agent:{realm}/{owner}/{name} -> {realm}
realm_from_mri(<<"mri:agent:", Rest/binary>>) ->
    case binary:split(Rest, <<"/">>, []) of
        [Realm, _] -> Realm;
        _ -> <<"io.macula">>
    end;
realm_from_mri(_) ->
    <<"io.macula">>.

gf(Key, Map) -> gf(Key, Map, undefined).
gf(Key, Map, Default) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, Default)
    end.
