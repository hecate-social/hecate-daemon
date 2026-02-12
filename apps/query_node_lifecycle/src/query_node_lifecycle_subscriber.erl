%%% @doc Consolidated event subscriber for all node lifecycle projections.
%%%
%%% Subscribes to 13 event types from hecate_event_store and routes
%%% each to the appropriate projection module.
-module(query_node_lifecycle_subscriber).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-dialyzer({nowarn_function, [init/1, terminate/2, handle_info/2]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {
    subscriptions :: [binary()],
    store_id :: atom(),
    event_count = 0 :: non_neg_integer(),
    error_count = 0 :: non_neg_integer()
}).

-define(EVENT_TYPES, [
    <<"identity_registered_v1">>,
    <<"identity_updated_v1">>,
    <<"capability_announced_v1">>,
    <<"capability_updated_v1">>,
    <<"capability_retracted_v1">>,
    <<"node_connected_v1">>,
    <<"node_disconnected_v1">>,
    <<"capability_endorsed_v1">>,
    <<"endorsement_revoked_v1">>,
    <<"topic_subscribed_v1">>,
    <<"topic_unsubscribed_v1">>,
    <<"ucan_granted_v1">>,
    <<"ucan_revoked_v1">>
]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    StoreId = hecate_event_store,
    Prefix = <<"query_node_lifecycle_">>,

    Subscriptions = lists:filtermap(fun(EventType) ->
        SubName = <<Prefix/binary, EventType/binary>>,
        case reckon_evoq_adapter:subscribe(
            StoreId, event_type, EventType, SubName,
            #{start_from => 0, subscriber_pid => self()}
        ) of
            {ok, SubId} ->
                logger:info("[query_node_lifecycle_subscriber] Subscribed to ~s", [EventType]),
                {true, SubId};
            {error, Reason} ->
                logger:warning("[query_node_lifecycle_subscriber] Failed to subscribe to ~s: ~p",
                              [EventType, Reason]),
                false
        end
    end, ?EVENT_TYPES),

    {ok, #state{subscriptions = Subscriptions, store_id = StoreId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = EventType, data = EventData} = Event}, State) ->
    #state{store_id = StoreId, event_count = Count, error_count = Errors} = State,

    case project_event(EventType, EventData) of
        ok ->
            SubName = <<"query_node_lifecycle_", EventType/binary>>,
            reckon_evoq_adapter:ack(StoreId, SubName,
                                    Event#evoq_event.stream_id,
                                    Event#evoq_event.version),
            {noreply, State#state{event_count = Count + 1}};
        {error, Reason} ->
            logger:error("[query_node_lifecycle_subscriber] Projection error for ~s: ~p",
                        [EventType, Reason]),
            {noreply, State#state{error_count = Errors + 1}}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscriptions = Subs, store_id = StoreId}) ->
    lists:foreach(fun(SubId) ->
        reckon_evoq_adapter:unsubscribe(StoreId, SubId)
    end, Subs).

%% ===================================================================
%% Internal: Route events to projection modules
%% ===================================================================

project_event(EventType, EventData) ->
    try
        do_project(EventType, EventData)
    catch
        Class:Reason:Stack ->
            logger:error("[query_node_lifecycle_subscriber] ~s projection exception: ~p:~p~n~p",
                        [EventType, Class, Reason, Stack]),
            {error, {projection_failed, Class, Reason}}
    end.

do_project(<<"identity_registered_v1">>, D) ->
    identity_registered_v1_to_identities:project(D);
do_project(<<"identity_updated_v1">>, D) ->
    identity_updated_v1_to_identities:project(D);
do_project(<<"capability_announced_v1">>, D) ->
    capability_announced_v1_to_capabilities:project(D);
do_project(<<"capability_updated_v1">>, D) ->
    capability_updated_v1_to_capabilities:project(D);
do_project(<<"capability_retracted_v1">>, D) ->
    capability_retracted_v1_to_capabilities:project(D);
do_project(<<"node_connected_v1">>, D) ->
    node_connected_v1_to_connections:project(D);
do_project(<<"node_disconnected_v1">>, D) ->
    node_disconnected_v1_to_connections:project(D);
do_project(<<"capability_endorsed_v1">>, D) ->
    capability_endorsed_v1_to_endorsements:project(D);
do_project(<<"endorsement_revoked_v1">>, D) ->
    endorsement_revoked_v1_to_endorsements:project(D);
do_project(<<"topic_subscribed_v1">>, D) ->
    topic_subscribed_v1_to_subscriptions:project(D);
do_project(<<"topic_unsubscribed_v1">>, D) ->
    topic_unsubscribed_v1_to_subscriptions:project(D);
do_project(<<"ucan_granted_v1">>, D) ->
    ucan_granted_v1_to_ucan_grants:project(D);
do_project(<<"ucan_revoked_v1">>, D) ->
    ucan_revoked_v1_to_ucan_grants:project(D);
do_project(UnknownType, _D) ->
    logger:warning("[query_node_lifecycle_subscriber] Unknown event type: ~p", [UnknownType]),
    {error, unknown_event_type}.
