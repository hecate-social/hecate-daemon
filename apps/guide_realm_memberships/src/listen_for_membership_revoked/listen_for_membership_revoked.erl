%%% @doc Mesh listener for realm-tier `membership/revoked` facts.
%%%
%%% Subscribes to `io.macula/_realm/_realm/membership/revoked_v1` ONLY
%%% after this daemon has actually joined a realm — wired by the
%%% `on_realm_membership_confirmed_subscribe_to_revoked` process
%%% manager which fires when a `realm_membership_confirmed_v1` event
%%% lands in the local event store. On `realm_membership_ended_v1`
%%% (whether by local resign or by a revoke we received from the
%%% realm), the symmetric PM
%%% `on_realm_membership_ended_unsubscribe_from_revoked` casts an
%%% unsubscribe so a former member doesn't keep listening.
%%%
%%% Per evoq's event handler semantics, both PMs replay historical
%%% events on daemon boot — so a daemon that was joined yesterday and
%%% restarts today will see the historical `realm_membership_confirmed_v1`
%%% replay, which casts `subscribe/1` here, restoring the live
%%% subscription. No periodic boot poll needed.
%%%
%%% own_mri is the confirmed member's DID, NOT the daemon's
%%% `hecate_identity:get_mri/0` MRI. The pre-3.0 listener subscribed
%%% as `mri:agent:io.macula/anonymous/hecate-...` BEFORE join, which
%%% meant the TargetDid match could never succeed. Now the gate is
%%% explicit: subscribe with the actual confirmed member_did.
%%% @end
-module(listen_for_membership_revoked).
-behaviour(gen_server).

-export([start_link/0, subscribe/1, unsubscribe/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(RETRY_MS, 10000).

-record(state, {
    sub_ref :: reference() | undefined,
    topic   :: binary() | undefined,
    own_mri :: binary() | undefined
}).

%%====================================================================
%% Public API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc Cast a request to subscribe to membership/revoked facts as
%% the given member DID. Idempotent — re-subscribing with the same
%% DID is a no-op; with a different DID it tears down the previous
%% subscription and rebinds.
-spec subscribe(binary()) -> ok.
subscribe(MemberDid) when is_binary(MemberDid) ->
    gen_server:cast(?SERVER, {subscribe, MemberDid}).

%% @doc Cast a request to drop any active membership-revoked
%% subscription. Idempotent.
-spec unsubscribe() -> ok.
unsubscribe() ->
    gen_server:cast(?SERVER, unsubscribe).

%%====================================================================
%% gen_server
%%====================================================================

init([]) ->
    %% Boot dormant — wait for the confirm-PM (or its replay) to fire
    %% subscribe/1.
    {ok, #state{}}.

handle_call(_, _From, State) -> {reply, {error, unknown_call}, State}.

handle_cast({subscribe, MemberDid}, #state{own_mri = MemberDid} = State) ->
    %% Already subscribed under this DID — no-op.
    {noreply, State};
handle_cast({subscribe, MemberDid}, State) ->
    handle_subscribe_request(MemberDid, drop_active_sub(State));
handle_cast(unsubscribe, State) ->
    {noreply, drop_active_sub(State)};
handle_cast(_, State) ->
    {noreply, State}.

handle_info({retry_subscribe, MemberDid}, State) ->
    handle_subscribe_request(MemberDid, State);
handle_info({mesh_membership_revoked, Msg}, State) ->
    handle_revoked_message(Msg, State),
    {noreply, State};
handle_info(_, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    _ = drop_active_sub(State),
    ok.

code_change(_, State, _) -> {ok, State}.

%%====================================================================
%% Internal — subscription lifecycle
%%====================================================================

handle_subscribe_request(MemberDid, State) ->
    case erlang:whereis(hecate_mesh_client) of
        undefined ->
            schedule_retry(MemberDid),
            {noreply, State};
        _Pid ->
            subscribe_now(MemberDid, State)
    end.

subscribe_now(MemberDid, State) ->
    Topic = hecate_topics:realm_fact(<<"membership">>, <<"revoked">>, 1),
    Self = self(),
    Callback = fun(Msg) -> Self ! {mesh_membership_revoked, Msg} end,
    case hecate_mesh:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[listen_for_membership_revoked] subscribed "
                        "topic=~s member_did=~s", [Topic, MemberDid]),
            {noreply, State#state{sub_ref = Ref, topic = Topic,
                                  own_mri = MemberDid}};
        {error, Reason} ->
            logger:warning("[listen_for_membership_revoked] subscribe "
                           "failed: ~p (will retry)", [Reason]),
            schedule_retry(MemberDid),
            {noreply, State}
    end.

drop_active_sub(#state{sub_ref = undefined} = State) ->
    State;
drop_active_sub(#state{sub_ref = Ref, own_mri = Mri} = State) ->
    _ = catch hecate_mesh:unsubscribe(Ref),
    logger:info("[listen_for_membership_revoked] unsubscribed member_did=~s",
                [Mri]),
    State#state{sub_ref = undefined, topic = undefined, own_mri = undefined}.

schedule_retry(MemberDid) ->
    erlang:send_after(?RETRY_MS, self(), {retry_subscribe, MemberDid}).

%%====================================================================
%% Internal — revoke message handling
%%====================================================================

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
maybe_dispatch_end(MId, TargetDid, EndedBy, OwnMri) when TargetDid =:= OwnMri ->
    dispatch_end(MId, EndedBy);
maybe_dispatch_end(_MId, _TargetDid, _EndedBy, _OwnMri) ->
    %% Revoke for some other member — not us. Quietly ignore.
    ok.

dispatch_end(MId, EndedBy) ->
    case end_realm_membership_v1:new(#{
             membership_id => MId,
             reason        => revoked,
             ended_by      => EndedBy,
             ended_at      => erlang:system_time(millisecond)}) of
        {ok, Cmd} ->
            log_result(MId, maybe_end_realm_membership:dispatch(Cmd));
        {error, R} ->
            logger:warning("[listen_for_membership_revoked] cmd build failed: ~p",
                           [R])
    end.

log_result(MId, {ok, _V, _Events}) ->
    logger:info("[listen_for_membership_revoked] ended membership=~s", [MId]);
log_result(MId, {error, already_ended}) ->
    logger:debug("[listen_for_membership_revoked] idempotent membership=~s",
                 [MId]);
log_result(MId, {error, Reason}) ->
    logger:info("[listen_for_membership_revoked] dispatch error membership=~s: ~p",
                [MId, Reason]).

%%====================================================================
%% Internal — payload helpers
%%====================================================================

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
