%%% @doc Mesh listener: `{realm}.membership.revoked` → dispatch
%%% `end_realm_membership_v1 {reason: :revoked, ended_by: admin_did}`
%%% when the fact's target DID matches this daemon's own MRI.
%%%
%%% The realm server is the authority for membership revocation. When
%%% an operator issues a revoke command on the realm server, a FACT is
%%% published on `{realm}.membership.revoked`. Each daemon listens; the
%%% one that matches the target DID ends its local membership.
%%%
%%% Boot-order guarded — waits for `hecate_mesh_client` + identity
%%% before subscribing (same pattern as `listen_for_license_revoked`).
%%% @end
-module(listen_for_membership_revoked).
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

handle_call(_, _From, State) -> {reply, {error, unknown_call}, State}.
handle_cast(_, State)        -> {noreply, State}.

handle_info(try_subscribe, State) ->
    handle_subscribe_attempt(State);
handle_info({mesh_membership_revoked, Msg}, State) ->
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
    Topic = hecate_topics:realm_fact(<<"membership">>, <<"revoked">>, 1),
    Self = self(),
    Callback = fun(Msg) -> Self ! {mesh_membership_revoked, Msg} end,
    case hecate_mesh:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[listen_for_membership_revoked] subscribed topic=~s mri=~s",
                        [Topic, Mri]),
            {noreply, State#state{sub_ref = Ref, topic = Topic, own_mri = Mri}};
        {error, Reason} ->
            logger:warning("[listen_for_membership_revoked] subscribe failed: ~p",
                           [Reason]),
            schedule_retry(),
            {noreply, State}
    end.

schedule_retry() ->
    erlang:send_after(?RETRY_MS, self(), try_subscribe).

handle_revoked_message(Msg, #state{own_mri = OwnMri}) ->
    Payload = extract_payload(Msg),
    TargetDid = gf(member_did, Payload),
    MembershipId = gf(membership_id, Payload),
    EndedBy = gf(revoked_by, Payload),
    maybe_dispatch_end(MembershipId, TargetDid, EndedBy, OwnMri).

maybe_dispatch_end(undefined, _Target, _EndedBy, _OwnMri) ->
    logger:warning("[listen_for_membership_revoked] missing membership_id");
maybe_dispatch_end(_MId, undefined, _EndedBy, _OwnMri) ->
    logger:warning("[listen_for_membership_revoked] missing member_did");
maybe_dispatch_end(MId, TargetDid, EndedBy, OwnMri) ->
    case TargetDid =:= OwnMri of
        true  -> dispatch_end(MId, EndedBy);
        false -> ok
    end.

dispatch_end(MId, EndedBy) ->
    case end_realm_membership_v1:new(#{
             membership_id => MId,
             reason        => revoked,
             ended_by      => EndedBy,
             ended_at      => erlang:system_time(millisecond)}) of
        {ok, Cmd} ->
            log_result(MId, maybe_end_realm_membership:dispatch(Cmd));
        {error, R} ->
            logger:warning("[listen_for_membership_revoked] cmd build failed: ~p", [R])
    end.

log_result(MId, {ok, _V, _Events}) ->
    logger:info("[listen_for_membership_revoked] ended membership=~s", [MId]);
log_result(MId, {error, already_ended}) ->
    logger:debug("[listen_for_membership_revoked] idempotent membership=~s", [MId]);
log_result(MId, {error, Reason}) ->
    logger:info("[listen_for_membership_revoked] dispatch error membership=~s: ~p",
                [MId, Reason]).

extract_payload(#{payload := P}) when is_map(P)    -> P;
extract_payload(#{payload := P}) when is_binary(P) -> decode_json(P);
extract_payload(P) when is_map(P)                  -> P;
extract_payload(P) when is_binary(P)               -> decode_json(P);
extract_payload(_)                                 -> #{}.

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
