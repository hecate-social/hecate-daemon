%%% @doc Mesh listener: `{realm}.licenses.revoked` → dispatch
%%% `end_license_v1` on the recipient side.
%%%
%%% Phase D Session 2 wires the LISTENER. The matching PUBLISHER lives
%%% on the issuer side and lands in Session 3 along with
%%% `revoke_share_license` (a new desk distinct from the existing
%%% appstore `revoke_license`). Until then this listener is idle.
%%%
%%% Guarded against boot-order like `listen_for_license_batch`.
%%% @end
-module(listen_for_license_revoked).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(RETRY_MS, 10000).

-record(state, {
    sub_ref :: reference() | undefined,
    topic   :: binary() | undefined,
    own_mri :: binary() | undefined
}).

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
    self() ! try_subscribe,
    {ok, #state{}}.

handle_call(_, _From, State)         -> {reply, {error, unknown_call}, State}.
handle_cast(_, State)                -> {noreply, State}.

handle_info(try_subscribe, State) ->
    handle_subscribe_attempt(State);
handle_info({mesh_license_revoked, Msg}, State) ->
    handle_revoked_message(Msg, State),
    {noreply, State};
handle_info(_, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_ref = undefined}) -> ok;
terminate(_Reason, #state{sub_ref = Ref}) ->
    _ = catch hecate_mesh:unsubscribe(Ref),
    ok.

code_change(_, State, _) -> {ok, State}.

%% --- Internal ---

handle_subscribe_attempt(State) ->
    case {erlang:whereis(hecate_mesh_client), hecate_identity_available()} of
        {undefined, _} ->
            schedule_retry(),
            {noreply, State};
        {_Pid, {ok, Mri}} ->
            subscribe_now(Mri, State);
        {_Pid, not_ready} ->
            schedule_retry(),
            {noreply, State}
    end.

hecate_identity_available() ->
    case erlang:whereis(hecate_identity) of
        undefined -> not_ready;
        _ ->
            case hecate_identity:get_mri() of
                {ok, Mri}       -> {ok, Mri};
                not_initialized -> not_ready
            end
    end.

subscribe_now(Mri, State) ->
    Topic = hecate_topics:org_fact(<<"licenses">>, <<"revoked">>, 1),
    Self = self(),
    Callback = fun(Msg) -> Self ! {mesh_license_revoked, Msg} end,
    case hecate_mesh:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[listen_for_license_revoked] subscribed topic=~s mri=~s",
                        [Topic, Mri]),
            {noreply, State#state{sub_ref = Ref, topic = Topic, own_mri = Mri}};
        {error, Reason} ->
            logger:warning("[listen_for_license_revoked] subscribe failed: ~p",
                           [Reason]),
            schedule_retry(),
            {noreply, State}
    end.

schedule_retry() ->
    erlang:send_after(?RETRY_MS, self(), try_subscribe).

handle_revoked_message(Msg, #state{own_mri = OwnMri}) ->
    Payload = extract_payload(Msg),
    LicenseId = gf(license_id, Payload),
    Grantee   = gf(grantee, Payload),
    Reason    = revoke_reason(gf(reason, Payload)),
    maybe_dispatch_end(LicenseId, Grantee, Reason, OwnMri).

maybe_dispatch_end(undefined, _Grantee, _Reason, _OwnMri) ->
    logger:warning("[listen_for_license_revoked] missing license_id");
maybe_dispatch_end(_LicenseId, undefined, _Reason, _OwnMri) ->
    logger:warning("[listen_for_license_revoked] missing grantee");
maybe_dispatch_end(LicenseId, Grantee, Reason, OwnMri) ->
    case grantee_matches(Grantee, OwnMri) of
        true  -> dispatch_end(LicenseId, Reason);
        false -> ok
    end.

grantee_matches(<<"mri:realm:", _/binary>>, _) -> true;
grantee_matches(G, G) when is_binary(G) -> true;
grantee_matches(_, _) -> false.

dispatch_end(LicenseId, Reason) ->
    Payload = #{license_id => LicenseId, reason => Reason},
    case end_license_v1:new(Payload) of
        {ok, Cmd} ->
            log_result(LicenseId, maybe_end_license:dispatch(Cmd));
        {error, R} ->
            logger:warning("[listen_for_license_revoked] cmd build failed: ~p", [R])
    end.

log_result(LicenseId, {ok, _V, _Events}) ->
    logger:info("[listen_for_license_revoked] ended license=~s", [LicenseId]);
log_result(LicenseId, {error, license_ended}) ->
    logger:debug("[listen_for_license_revoked] idempotent license=~s", [LicenseId]);
log_result(LicenseId, {error, Reason}) ->
    logger:info("[listen_for_license_revoked] dispatch error license=~s: ~p",
                [LicenseId, Reason]).

revoke_reason(undefined) -> revoked;
revoke_reason(B) when is_binary(B) ->
    try binary_to_existing_atom(B, utf8)
    catch _:_ -> revoked
    end;
revoke_reason(A) when is_atom(A) -> A;
revoke_reason(_) -> revoked.

extract_payload(#{payload := P}) when is_map(P) -> P;
extract_payload(#{payload := P}) when is_binary(P) -> decode_json(P);
extract_payload(P) when is_map(P) -> P;
extract_payload(P) when is_binary(P) -> decode_json(P);
extract_payload(_) -> #{}.

decode_json(Bin) ->
    try json:decode(Bin) of
        Map when is_map(Map) -> Map;
        _ -> #{}
    catch _:_ -> #{}
    end.

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
