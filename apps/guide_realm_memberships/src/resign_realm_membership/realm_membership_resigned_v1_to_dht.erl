%%% @doc Emitter: realm_membership_resigned_v1 → signed DHT record
%%% (`realm_member_resigned_v1', type tag `0x21').
%%%
%%% Replaces the V1 mesh-pub/sub emitter. The realm server picks this
%%% up via `find_records_by_type(0x21)' and triggers K_realm rotation
%%% after the existing 60s debounce window.
%%%
%%% Storage key derives from `subject_id = membership_id' so each
%%% resignation lands in its own DHT slot — a single daemon can resign
%%% from multiple realms over its lifetime without overwriting prior
%%% records.
%%%
%%% Signed with the daemon's Ed25519 keypair so the realm can verify
%%% the resigning member is the same identity that originally joined.
%%% @end
-module(realm_membership_resigned_v1_to_dht).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

%% Domain-defined record type (PLAN_DHT_FIRST.md §1).
-define(TYPE_REALM_MEMBER_RESIGNED_V1, 16#21).

%% Resignations are terminal — keep the record around for 90 days
%% so the realm has plenty of time to react and rotate keys before
%% the record evaporates.
-define(DEFAULT_TTL_MS, 90 * 24 * 60 * 60 * 1000).

interested_in() -> [<<"realm_membership_resigned_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(<<"realm_membership_resigned_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    put_record_or_log(Data),
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.

%% --- Internal ---

put_record_or_log(Data) ->
    case gf(membership_id, Data) of
        undefined ->
            logger:warning("[realm_membership_resigned_v1_to_dht] "
                           "missing membership_id");
        MId ->
            do_put(MId, Data)
    end.

do_put(MId, Data) ->
    case erlang:whereis(hecate_mesh_client) of
        undefined ->
            logger:info("[realm_membership_resigned_v1_to_dht] mesh down; "
                        "drop resign ~s", [MId]);
        _Pid ->
            do_put_with_mesh(MId, Data)
    end.

do_put_with_mesh(MId, Data) ->
    case hecate_identity:signing_keypair() of
        {ok, KeyPair} ->
            do_put_signed(KeyPair, MId, Data);
        not_initialized ->
            logger:warning("[realm_membership_resigned_v1_to_dht] "
                           "identity not initialised; skipping ~s", [MId])
    end.

do_put_signed(KeyPair, MId, Data) ->
    Payload = #{
        {text, <<"membership_id">>} => MId,
        {text, <<"realm_id">>}      => bin_or_empty(gf(realm_id,   Data)),
        {text, <<"member_did">>}    => bin_or_empty(gf(member_did, Data)),
        {text, <<"resigned_at">>}   => gf(resigned_at, Data,
                                          erlang:system_time(millisecond))
    },
    SignerPub = macula_identity:public(KeyPair),
    Unsigned = macula_record:envelope(?TYPE_REALM_MEMBER_RESIGNED_V1,
                                       SignerPub, Payload,
                                       #{ttl_ms    => ?DEFAULT_TTL_MS,
                                         subject_id => sha256(MId)}),
    Signed = macula_record:sign(Unsigned, KeyPair),
    case hecate_mesh:put_record(Signed) of
        ok ->
            logger:info("[realm_membership_resigned_v1_to_dht] ~s -> 0x21 record",
                        [MId]);
        {error, Reason} ->
            logger:warning("[realm_membership_resigned_v1_to_dht] "
                           "put_record failed ~s: ~p", [MId, Reason])
    end.

bin_or_empty(undefined)              -> <<>>;
bin_or_empty(B) when is_binary(B)    -> B;
bin_or_empty(L) when is_list(L)      -> list_to_binary(L);
bin_or_empty(O)                      -> term_to_binary(O).

sha256(Bin) when is_binary(Bin) -> crypto:hash(sha256, Bin);
sha256(L)   when is_list(L)     -> crypto:hash(sha256, list_to_binary(L)).

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
