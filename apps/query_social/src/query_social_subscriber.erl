%%% @doc Event subscriber for query_social
%%% Subscribes to social events and triggers projections.
-module(query_social_subscriber).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [init/1, terminate/2, handle_info/2]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {
    subscriptions :: [binary()],
    store_id :: atom(),
    event_count = 0 :: non_neg_integer()
}).

-define(SOCIAL_EVENT_TYPES, [
    <<"agent_followed_v1">>,
    <<"agent_unfollowed_v1">>,
    <<"capability_endorsed_v1">>,
    <<"endorsement_revoked_v1">>
]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    StoreId = manage_social_db,
    SubscriptionPrefix = <<"query_social_">>,

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
                io:format("[query_social_subscriber] Subscribed to ~s~n", [EventType]),
                {true, SubId};
            {error, _Reason} ->
                false
        end
    end, ?SOCIAL_EVENT_TYPES),

    {ok, #state{subscriptions = Subscriptions, store_id = StoreId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = EventType, data = EventData} = Event}, State) ->
    #state{store_id = StoreId, event_count = Count} = State,

    ProjectionResult = project_event(EventType, EventData),

    case ProjectionResult of
        ok ->
            SubName = <<"query_social_", EventType/binary>>,
            reckon_evoq_adapter:ack(StoreId, SubName,
                                    Event#evoq_event.stream_id, Event#evoq_event.version),
            {noreply, State#state{event_count = Count + 1}};
        {error, Reason} ->
            io:format("[query_social_subscriber] Projection error for ~s: ~p~n", [EventType, Reason]),
            {noreply, State}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscriptions = Subs, store_id = StoreId}) ->
    lists:foreach(fun(SubId) ->
        reckon_evoq_adapter:unsubscribe(StoreId, SubId)
    end, Subs).

%% Internal: Route events to appropriate projections

project_event(<<"agent_followed_v1">>, EventData) ->
    agent_followed_v1_to_followers:project(EventData);
project_event(<<"agent_unfollowed_v1">>, EventData) ->
    agent_unfollowed_v1_to_followers:project(EventData);
project_event(<<"capability_endorsed_v1">>, EventData) ->
    capability_endorsed_v1_to_endorsements:project(EventData);
project_event(<<"endorsement_revoked_v1">>, EventData) ->
    endorsement_revoked_v1_to_endorsements:project(EventData);
project_event(_UnknownType, _EventData) ->
    {error, unknown_event_type}.
