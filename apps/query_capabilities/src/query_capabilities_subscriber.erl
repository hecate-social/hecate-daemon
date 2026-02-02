%%% @doc Event subscriber for query_capabilities
%%% Subscribes to capability_announced_v1 events from manage_capabilities_db
%%% and automatically triggers projections to update the read model.
-module(query_capabilities_subscriber).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [init/1, terminate/2, handle_event/2]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {
    subscription_id :: binary() | undefined,
    store_id :: atom(),
    event_count = 0 :: non_neg_integer(),
    error_count = 0 :: non_neg_integer()
}).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    %% Subscribe to capability_announced_v1 events from manage_capabilities_db
    StoreId = manage_capabilities_db,
    SubscriptionName = <<"query_capabilities_subscriber">>,

    Opts = #{
        start_from => 0,  %% Start from beginning (replay all events)
        subscriber_pid => self()
    },

    case reckon_evoq_adapter:subscribe(
        StoreId,
        event_type,
        <<"capability_announced_v1">>,
        SubscriptionName,
        Opts
    ) of
        {ok, SubscriptionId} ->
            io:format("~n[query_capabilities_subscriber] Subscribed to capability_announced_v1 events (ID: ~s)~n", [SubscriptionId]),
            {ok, #state{
                subscription_id = SubscriptionId,
                store_id = StoreId
            }};
        {error, Reason} ->
            io:format("~n[query_capabilities_subscriber] ERROR: Failed to subscribe: ~p~n", [Reason]),
            {stop, {subscription_failed, Reason}}
    end.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Handle incoming events from subscription
handle_info({event, Event}, State) ->
    handle_event(Event, State);

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_id = SubId, store_id = StoreId}) ->
    case SubId of
        undefined -> ok;
        _ ->
            reckon_evoq_adapter:unsubscribe(StoreId, SubId),
            io:format("~n[query_capabilities_subscriber] Unsubscribed~n")
    end,
    ok.

%%====================================================================
%% Internal functions
%%====================================================================

%% Handle an event from the subscription
handle_event(#evoq_event{event_type = <<"capability_announced_v1">>, data = EventData} = Event, State) ->
    #state{store_id = StoreId, event_count = Count, error_count = Errors} = State,

    io:format("[query_capabilities_subscriber] Received event: ~s~n", [<<"capability_announced_v1">>]),

    %% Project the event to the read model
    case project_event(EventData) of
        ok ->
            %% Ack the event
            StreamId = Event#evoq_event.stream_id,
            Version = Event#evoq_event.version,
            SubscriptionName = <<"query_capabilities_subscriber">>,
            reckon_evoq_adapter:ack(StoreId, SubscriptionName, StreamId, Version),

            io:format("[query_capabilities_subscriber] Projected event successfully (total: ~p)~n", [Count + 1]),
            {noreply, State#state{event_count = Count + 1}};

        {error, Reason} ->
            io:format("[query_capabilities_subscriber] ERROR: Projection failed: ~p~n", [Reason]),
            %% Don't ack - allow retry
            %% TODO: Implement dead letter queue after N retries
            {noreply, State#state{error_count = Errors + 1}}
    end;

handle_event(Event, State) ->
    %% Unexpected event type
    io:format("[query_capabilities_subscriber] WARNING: Unexpected event type: ~p~n", [Event#evoq_event.event_type]),
    {noreply, State}.

%% Project event to read model
project_event(EventData) ->
    try
        capability_announced_v1_to_capabilities:project(EventData)
    catch
        Class:Reason:Stacktrace ->
            io:format("[query_capabilities_subscriber] Projection exception: ~p:~p~n~p~n",
                      [Class, Reason, Stacktrace]),
            {error, {projection_failed, Class, Reason}}
    end.
