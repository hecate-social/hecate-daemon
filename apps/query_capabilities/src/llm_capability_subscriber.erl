%%% @doc Event subscriber for LLM capabilities
%%% Subscribes to llm_capability_* events from serve_llm_store
%%% and triggers projections to update the capabilities read model.
-module(llm_capability_subscriber).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [init/1, terminate/2, subscribe_to_events/1]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {
    subscriptions :: #{binary() => binary()},  %% event_type => sub_id
    store_id :: atom(),
    event_count = 0 :: non_neg_integer()
}).

-define(STORE_ID, serve_llm_store).
-define(EVENT_TYPES, [
    <<"llm_capability_announced_v1">>,
    <<"llm_capability_retracted_v1">>,
    <<"llm_status_updated_v1">>
]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Subscribe to LLM events from serve_llm_store
    Subscriptions = subscribe_to_events(?EVENT_TYPES),
    logger:info("[llm_capability_subscriber] Subscribed to ~p event types", [map_size(Subscriptions)]),
    {ok, #state{
        subscriptions = Subscriptions,
        store_id = ?STORE_ID
    }}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = EventType, data = EventData}}, State) ->
    #state{event_count = Count} = State,
    %% Route to appropriate projection
    case project_event(EventType, EventData) of
        ok ->
            {noreply, State#state{event_count = Count + 1}};
        {error, Reason} ->
            logger:warning("[llm_capability_subscriber] Projection failed: ~p", [Reason]),
            {noreply, State}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscriptions = Subs}) ->
    maps:foreach(fun(_EventType, SubId) ->
        reckon_evoq_adapter:unsubscribe(?STORE_ID, SubId)
    end, Subs),
    ok.

%% Internal

subscribe_to_events(EventTypes) ->
    lists:foldl(fun(EventType, Acc) ->
        SubName = <<"llm_cap_sub_", EventType/binary>>,
        Opts = #{start_from => 0, subscriber_pid => self()},
        case reckon_evoq_adapter:subscribe(?STORE_ID, event_type, EventType, SubName, Opts) of
            {ok, SubId} ->
                Acc#{EventType => SubId};
            {error, Reason} ->
                logger:warning("[llm_capability_subscriber] Failed to subscribe to ~s: ~p",
                              [EventType, Reason]),
                Acc
        end
    end, #{}, EventTypes).

project_event(<<"llm_capability_announced_v1">>, EventData) ->
    llm_capability_announced_v1_to_capabilities:project(EventData);
project_event(<<"llm_capability_retracted_v1">>, EventData) ->
    llm_capability_retracted_v1_to_capabilities:project(EventData);
project_event(<<"llm_status_updated_v1">>, EventData) ->
    llm_status_updated_v1_to_capabilities:project(EventData);
project_event(EventType, _EventData) ->
    logger:warning("[llm_capability_subscriber] Unknown event type: ~s", [EventType]),
    ok.
