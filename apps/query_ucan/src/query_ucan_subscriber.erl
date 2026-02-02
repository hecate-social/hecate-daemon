%%% @doc Event subscriber for query_ucan
%%% Subscribes to capability_granted_v1 and capability_revoked_v1 events.
-module(query_ucan_subscriber).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [init/1, terminate/2, project_and_ack/4]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {
    subscriptions = [] :: [binary()],
    store_id :: atom()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    StoreId = manage_ucan_db,

    {ok, SubId1} = reckon_evoq_adapter:subscribe(
        StoreId, event_type, <<"capability_granted_v1">>,
        <<"query_ucan_granted">>,
        #{start_from => 0, subscriber_pid => self()}
    ),

    {ok, SubId2} = reckon_evoq_adapter:subscribe(
        StoreId, event_type, <<"capability_revoked_v1">>,
        <<"query_ucan_revoked">>,
        #{start_from => 0, subscriber_pid => self()}
    ),

    io:format("~n[query_ucan_subscriber] Subscribed to UCAN events~n"),
    {ok, #state{subscriptions = [SubId1, SubId2], store_id = StoreId}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = <<"capability_granted_v1">>, data = Data} = Event}, State) ->
    project_and_ack(Data, Event, State, fun capability_granted_v1_to_capabilities:project/1);

handle_info({event, #evoq_event{event_type = <<"capability_revoked_v1">>, data = Data} = Event}, State) ->
    project_and_ack(Data, Event, State, fun capability_revoked_v1_to_capabilities:project/1);

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscriptions = Subs, store_id = StoreId}) ->
    [reckon_evoq_adapter:unsubscribe(StoreId, S) || S <- Subs],
    ok.

%% Internal
project_and_ack(EventData, Event, State, ProjectFun) ->
    #state{store_id = StoreId} = State,
    case ProjectFun(EventData) of
        ok ->
            reckon_evoq_adapter:ack(StoreId, element(2, erlang:process_info(self(), registered_name)),
                                    Event#evoq_event.stream_id, Event#evoq_event.version),
            {noreply, State};
        {error, Reason} ->
            io:format("[query_ucan_subscriber] Projection error: ~p~n", [Reason]),
            {noreply, State}
    end.
