%%% @doc Emitter: share_license_revoked_v1 domain event → mesh FACT on
%%% `{realm}.licenses.revoked`.
%%%
%%% Revocations are NOT batched — each revoke is published immediately
%%% so recipients clear `CEK_USABLE` promptly. The matching recipient-
%%% side listener is `listen_for_license_revoked` which dispatches
%%% `end_license_v1` against `accepted_license_aggregate`.
%%% @end
-module(share_license_revoked_v1_to_mesh).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"share_license_revoked_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(<<"share_license_revoked_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    publish(Data),
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.

%% --- Internal ---

publish(Data) ->
    case {gf(license_id, Data), gf(realm, Data)} of
        {undefined, _} ->
            logger:warning("[share_license_revoked_v1_to_mesh] missing license_id");
        {_, undefined} ->
            logger:warning("[share_license_revoked_v1_to_mesh] missing realm");
        {LicenseId, _Realm} ->
            do_publish(LicenseId, Data)
    end.

do_publish(LicenseId, Data) ->
    case erlang:whereis(hecate_mesh_client) of
        undefined ->
            logger:info("[share_license_revoked_v1_to_mesh] mesh down; drop revoke license=~s",
                        [LicenseId]);
        _Pid ->
            Topic = hecate_topics:fact(<<"licenses">>, <<"revoked">>, 1),
            Fact = #{
                license_id => LicenseId,
                grantee    => gf(grantee,    Data),
                realm      => gf(realm,      Data),
                issuer_did => gf(issuer_did, Data),
                reason     => encode_reason(gf(reason, Data, revoked)),
                revoked_at => gf(revoked_at, Data, erlang:system_time(millisecond))
            },
            case hecate_mesh:publish(Topic, Fact) of
                ok ->
                    logger:info("[share_license_revoked_v1_to_mesh] ~s -> ~s",
                                [LicenseId, Topic]);
                {error, Reason} ->
                    logger:warning("[share_license_revoked_v1_to_mesh] publish failed ~s: ~p",
                                   [LicenseId, Reason])
            end
    end.

encode_reason(A) when is_atom(A) -> atom_to_binary(A, utf8);
encode_reason(B) when is_binary(B) -> B;
encode_reason(_) -> <<"revoked">>.

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
