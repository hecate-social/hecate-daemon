%%% @doc Emitter: identity_public_key_announced_v1 domain event → signed
%%% DHT record (`realm_member_identity_v1', type tag `0x20').
%%%
%%% Replaces the V1 mesh-pub/sub emitter. Per PLAN_DHT_FIRST.md the
%%% realm picks up these records via `find_records_by_type(0x20)' on
%%% its mesh-subscriber side; pub/sub on the station is no longer
%%% load-bearing.
%%%
%%% The record is signed with the daemon's Ed25519 signing keypair —
%%% the storage key falls out as the signer's pubkey, so each daemon
%%% owns exactly one DHT slot and republishes at the same slot when
%%% the announcement re-fires (e.g. on key rotation).
%%%
%%% The encryption pubkey (X25519, used for DID-scope license
%%% wrapping) ships base64-encoded inside the payload — same shape
%%% as the V1 fact so the realm projection layer is unchanged.
%%% @end
-module(identity_public_key_announced_v1_to_dht).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

%% Domain-defined record type (PLAN_DHT_FIRST.md §1).
-define(TYPE_REALM_MEMBER_IDENTITY_V1, 16#20).

%% 30 days — long enough that a healthy daemon refreshes via
%% next-announcement before TTL elapses; the realm tolerates the
%% record disappearing a few hours before the daemon notices.
-define(DEFAULT_TTL_MS, 30 * 24 * 60 * 60 * 1000).

interested_in() ->
    [<<"identity_public_key_announced_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(<<"identity_public_key_announced_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    put_record_or_log(Data),
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.

%%%===================================================================
%%% Internal
%%%===================================================================

put_record_or_log(Data) ->
    Mri = gf(mri, Data),
    Pub = gf(encryption_public_key, Data),
    case {Mri, Pub} of
        {undefined, _} ->
            logger:warning("[announce_pubkey_dht] missing mri");
        {_, undefined} ->
            logger:warning("[announce_pubkey_dht] missing encryption_public_key");
        _ ->
            do_put(Mri, Pub, Data)
    end.

do_put(Mri, EncPub, Data) ->
    case hecate_identity:signing_keypair() of
        {ok, KeyPair} ->
            do_put_signed(KeyPair, Mri, EncPub, Data);
        not_initialized ->
            logger:warning("[announce_pubkey_dht] identity not initialised; "
                           "skipping DHT put for ~s", [Mri])
    end.

do_put_signed(KeyPair, Mri, EncPub, Data) ->
    Realm = realm_from_mri(Mri),
    AnnouncedAt = gf(announced_at, Data,
                     erlang:system_time(millisecond)),
    Payload = #{
        {text, <<"mri">>}                   => Mri,
        {text, <<"realm">>}                 => Realm,
        {text, <<"encryption_public_key">>} => base64:encode(EncPub),
        {text, <<"announced_at">>}          => AnnouncedAt
    },
    SignerPub = macula_identity:public(KeyPair),
    Unsigned = macula_record:envelope(?TYPE_REALM_MEMBER_IDENTITY_V1,
                                       SignerPub, Payload,
                                       #{ttl_ms => ?DEFAULT_TTL_MS}),
    Signed = macula_record:sign(Unsigned, KeyPair),
    case hecate_mesh:put_record(Signed) of
        ok ->
            logger:info("[announce_pubkey_dht] ~s -> 0x20 record",
                        [Mri]);
        {error, Reason} ->
            logger:warning("[announce_pubkey_dht] put_record failed ~s: ~p",
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
