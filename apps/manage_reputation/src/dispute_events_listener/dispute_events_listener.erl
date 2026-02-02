%%% @doc Listener: Dispute events (filtered)
%%%
%%% Subscribes to dispute.flagged and dispute.resolved mesh facts.
%%% Filters by MY_IDENTITIES - only processes facts where accused is ME.
%%% Dispatches commands to record disputes against my services.
-module(dispute_events_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    sub_flagged :: reference() | undefined,
    sub_resolved :: reference() | undefined
}).

%% API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Callbacks

init([]) ->
    self() ! subscribe,
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    SubFlagged = subscribe_to_topic(<<"hecate.dispute.flagged">>),
    SubResolved = subscribe_to_topic(<<"hecate.dispute.resolved">>),
    {noreply, State#state{sub_flagged = SubFlagged, sub_resolved = SubResolved}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_flagged = SubF, sub_resolved = SubR}) ->
    unsubscribe(SubF),
    unsubscribe(SubR),
    ok.

%% Internal

subscribe_to_topic(Topic) ->
    Callback = fun(EventData) -> handle_fact(Topic, EventData) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} ->
            logger:info("[dispute_events_listener] Subscribed to ~s", [Topic]),
            SubRef;
        {error, Reason} ->
            logger:warning("[dispute_events_listener] Failed to subscribe to ~s: ~p", [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(SubRef) -> hecate_mesh_client:unsubscribe(SubRef).

handle_fact(<<"hecate.dispute.flagged">>, EventData) ->
    handle_flagged(EventData);
handle_fact(<<"hecate.dispute.resolved">>, EventData) ->
    handle_resolved(EventData).

handle_flagged(EventData) ->
    #{
        <<"dispute_id">> := DisputeId,
        <<"flagger_identity">> := FlaggerIdentity,
        <<"accused_identity">> := AccusedIdentity,
        <<"reason">> := Reason,
        <<"flagged_at">> := FlaggedAt
    } = EventData,

    CallId = maps:get(<<"call_id">>, EventData, undefined),

    %% Only process if the accused is ME
    case is_my_identity(AccusedIdentity) of
        true ->
            logger:info("[dispute_events_listener] Dispute ~s filed against me by ~s",
                       [DisputeId, FlaggerIdentity]),
            Cmd = record_dispute_against_me_v1:new(
                DisputeId, FlaggerIdentity, AccusedIdentity, CallId, Reason, FlaggedAt
            ),
            case maybe_record_dispute_against_me:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[dispute_events_listener] Recorded dispute against me: ~s",
                                [DisputeId]);
                {error, Reason2} ->
                    logger:warning("[dispute_events_listener] Failed to record dispute: ~p", [Reason2])
            end;
        false ->
            ok  %% Not about me - ignore
    end.

handle_resolved(EventData) ->
    #{
        <<"dispute_id">> := DisputeId,
        <<"accused_identity">> := AccusedIdentity,
        <<"resolution">> := Resolution,
        <<"resolved_at">> := ResolvedAt
    } = EventData,

    ResolverIdentity = maps:get(<<"resolver_identity">>, EventData, undefined),
    Notes = maps:get(<<"notes">>, EventData, undefined),

    case is_my_identity(AccusedIdentity) of
        true ->
            logger:info("[dispute_events_listener] Dispute ~s resolved: ~s",
                       [DisputeId, Resolution]),
            Cmd = record_dispute_resolution_v1:new(
                DisputeId, AccusedIdentity, Resolution, ResolverIdentity, Notes, ResolvedAt
            ),
            case maybe_record_dispute_resolution:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:debug("[dispute_events_listener] Recorded dispute resolution: ~s",
                                [DisputeId]);
                {error, Reason} ->
                    logger:warning("[dispute_events_listener] Failed to record resolution: ~p", [Reason])
            end;
        false ->
            ok
    end.

is_my_identity(Identity) ->
    ManagedIdentities = application:get_env(hecate, managed_identities, []),
    lists:member(Identity, ManagedIdentities).
