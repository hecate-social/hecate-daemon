%%% @doc Event subscriber for query_identities
%%% Subscribes to identity events and triggers projections.
-module(query_identities_subscriber).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [init/1, terminate/2, handle_info/2]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {
    subscriptions :: [binary()],
    store_id :: atom()
}).

-define(IDENTITY_EVENT_TYPES, [
    <<"identity_registered_v1">>,
    <<"identity_updated_v1">>
]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    StoreId = manage_identities_db,
    SubscriptionPrefix = <<"query_identities_">>,

    Subscriptions = lists:filtermap(fun(EventType) ->
        SubName = <<SubscriptionPrefix/binary, EventType/binary>>,
        case reckon_evoq_adapter:subscribe(
            StoreId,
            event_type,
            EventType,
            SubName,
            #{start_from => 0, subscriber_pid => self()}
        ) of
            {ok, SubId} ->
                io:format("[query_identities_subscriber] Subscribed to ~s~n", [EventType]),
                {true, SubId};
            {error, _Reason} ->
                false
        end
    end, ?IDENTITY_EVENT_TYPES),

    {ok, #state{subscriptions = Subscriptions, store_id = StoreId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = EventType, data = Data} = Event}, State) ->
    #state{store_id = StoreId} = State,

    ProjectionResult = project_event(EventType, Data),

    case ProjectionResult of
        ok ->
            SubName = <<"query_identities_", EventType/binary>>,
            reckon_evoq_adapter:ack(StoreId, SubName,
                                    Event#evoq_event.stream_id, Event#evoq_event.version),
            {noreply, State};
        {error, Reason} ->
            io:format("[query_identities_subscriber] Projection error for ~s: ~p~n", [EventType, Reason]),
            {noreply, State}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscriptions = Subs, store_id = StoreId}) ->
    lists:foreach(fun(SubId) ->
        reckon_evoq_adapter:unsubscribe(StoreId, SubId)
    end, Subs).

%% Internal: Route events to appropriate projections

project_event(<<"identity_registered_v1">>, EventData) ->
    identity_registered_v1_to_identities:project(EventData);
project_event(<<"identity_updated_v1">>, EventData) ->
    identity_updated_v1_to_identities:project(EventData);
project_event(_UnknownType, _EventData) ->
    {error, unknown_event_type}.
