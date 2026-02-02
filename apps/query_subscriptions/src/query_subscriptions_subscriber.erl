%%% @doc Event subscriber for query_subscriptions
%%% Subscribes to subscribed_v1 and unsubscribed_v1 events.
-module(query_subscriptions_subscriber).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [init/1, terminate/2, project_and_ack/4]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {
    subscriptions = [] :: [binary()],
    store_id :: atom(),
    event_count = 0 :: non_neg_integer()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    StoreId = manage_subscriptions_db,

    %% Subscribe to both event types
    {ok, SubId1} = reckon_evoq_adapter:subscribe(
        StoreId, event_type, <<"subscribed_v1">>,
        <<"query_subscriptions_subscribed">>,
        #{start_from => 0, subscriber_pid => self()}
    ),

    {ok, SubId2} = reckon_evoq_adapter:subscribe(
        StoreId, event_type, <<"unsubscribed_v1">>,
        <<"query_subscriptions_unsubscribed">>,
        #{start_from => 0, subscriber_pid => self()}
    ),

    io:format("~n[query_subscriptions_subscriber] Subscribed to subscription events~n"),
    {ok, #state{subscriptions = [SubId1, SubId2], store_id = StoreId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = <<"subscribed_v1">>, data = Data} = Event}, State) ->
    project_and_ack(Data, Event, State, fun subscribed_v1_to_subscriptions:project/1);

handle_info({event, #evoq_event{event_type = <<"unsubscribed_v1">>, data = Data} = Event}, State) ->
    project_and_ack(Data, Event, State, fun unsubscribed_v1_to_subscriptions:project/1);

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscriptions = Subs, store_id = StoreId}) ->
    [reckon_evoq_adapter:unsubscribe(StoreId, S) || S <- Subs],
    ok.

%% Internal
project_and_ack(EventData, Event, State, ProjectFun) ->
    #state{store_id = StoreId, event_count = Count} = State,
    case ProjectFun(EventData) of
        ok ->
            reckon_evoq_adapter:ack(StoreId, element(1, erlang:process_info(self(), registered_name)),
                                    Event#evoq_event.stream_id, Event#evoq_event.version),
            {noreply, State#state{event_count = Count + 1}};
        {error, Reason} ->
            io:format("[query_subscriptions_subscriber] Projection error: ~p~n", [Reason]),
            {noreply, State}
    end.
