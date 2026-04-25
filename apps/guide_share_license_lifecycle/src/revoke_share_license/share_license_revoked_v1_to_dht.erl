%%% @doc Emitter: share_license_revoked_v1 → signed DHT record
%%% (`license_revoked_v1', type tag `0x24').
%%%
%%% Replaces the V1 mesh-pub/sub emitter. Per PLAN_DHT_FIRST.md the
%%% realm picks revocations up via `find_records_by_type(0x24)' and
%%% recipient daemons learn via the same path.
%%%
%%% Storage key derives from `subject_id = sha256(license_id)' so each
%%% revoked license owns a unique DHT slot. Re-issued licenses with a
%%% new id get a new slot; revocations of the same id-twice (idempotent)
%%% land at the same slot and the latest signed version wins.
%%% @end
-module(share_license_revoked_v1_to_dht).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

%% Domain-defined record type (PLAN_DHT_FIRST.md §1).
-define(TYPE_LICENSE_REVOKED_V1, 16#24).

%% Revocations propagate fast but the record survives long enough
%% (90 days) for offline recipients to learn on next reconnect.
-define(DEFAULT_TTL_MS, 90 * 24 * 60 * 60 * 1000).

interested_in() -> [<<"share_license_revoked_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(<<"share_license_revoked_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    put_record_or_log(Data),
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.

%% --- Internal ---

put_record_or_log(Data) ->
    case {gf(license_id, Data), gf(realm, Data)} of
        {undefined, _} ->
            logger:warning("[share_license_revoked_v1_to_dht] missing license_id");
        {_, undefined} ->
            logger:warning("[share_license_revoked_v1_to_dht] missing realm");
        {LicenseId, _Realm} ->
            do_put(LicenseId, Data)
    end.

do_put(LicenseId, Data) ->
    case erlang:whereis(hecate_mesh_client) of
        undefined ->
            logger:info("[share_license_revoked_v1_to_dht] mesh down; "
                        "drop revoke license=~s", [LicenseId]);
        _Pid ->
            do_put_with_mesh(LicenseId, Data)
    end.

do_put_with_mesh(LicenseId, Data) ->
    case hecate_identity:signing_keypair() of
        {ok, KeyPair} ->
            do_put_signed(KeyPair, LicenseId, Data);
        not_initialized ->
            logger:warning("[share_license_revoked_v1_to_dht] identity "
                           "not initialised; skipping ~s", [LicenseId])
    end.

do_put_signed(KeyPair, LicenseId, Data) ->
    Payload = #{
        {text, <<"license_id">>} => LicenseId,
        {text, <<"grantee">>}    => bin_or_empty(gf(grantee,    Data)),
        {text, <<"realm">>}      => bin_or_empty(gf(realm,      Data)),
        {text, <<"issuer_did">>} => bin_or_empty(gf(issuer_did, Data)),
        {text, <<"reason">>}     => encode_reason(gf(reason, Data, revoked)),
        {text, <<"revoked_at">>} => gf(revoked_at, Data,
                                       erlang:system_time(millisecond))
    },
    SignerPub = macula_identity:public(KeyPair),
    Unsigned = macula_record:envelope(?TYPE_LICENSE_REVOKED_V1,
                                       SignerPub, Payload,
                                       #{ttl_ms     => ?DEFAULT_TTL_MS,
                                         subject_id => sha256(LicenseId)}),
    Signed = macula_record:sign(Unsigned, KeyPair),
    case hecate_mesh:put_record(Signed) of
        ok ->
            logger:info("[share_license_revoked_v1_to_dht] ~s -> 0x24 record",
                        [LicenseId]);
        {error, Reason} ->
            logger:warning("[share_license_revoked_v1_to_dht] put_record "
                           "failed ~s: ~p", [LicenseId, Reason])
    end.

encode_reason(A) when is_atom(A)   -> atom_to_binary(A, utf8);
encode_reason(B) when is_binary(B) -> B;
encode_reason(_)                   -> <<"revoked">>.

bin_or_empty(undefined)              -> <<>>;
bin_or_empty(B) when is_binary(B)    -> B;
bin_or_empty(L) when is_list(L)      -> list_to_binary(L);
bin_or_empty(O)                      -> term_to_binary(O).

sha256(B) when is_binary(B) -> crypto:hash(sha256, B);
sha256(L) when is_list(L)   -> crypto:hash(sha256, list_to_binary(L)).

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
