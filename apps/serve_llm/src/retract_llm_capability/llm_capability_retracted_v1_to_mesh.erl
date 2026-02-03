%%% @doc Mesh emitter: llm_capability_retracted_v1 → Macula Mesh
%%% Projects LLM capability retractions to the mesh as integration facts.
-module(llm_capability_retracted_v1_to_mesh).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [init/1, terminate/2]}).

-include_lib("evoq/include/evoq_types.hrl").

-record(state, {subscription_id :: binary() | undefined}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Subscribe to llm_capability_retracted_v1 events from serve_llm_store
    case reckon_evoq_adapter:subscribe(
        serve_llm_store,
        event_type,
        <<"llm_capability_retracted_v1">>,
        <<"mesh_llm_capability_retracted">>,
        #{start_from => 0, subscriber_pid => self()}
    ) of
        {ok, SubId} ->
            logger:info("[llm_capability_retracted_v1_to_mesh] Subscribed to events"),
            {ok, #state{subscription_id = SubId}};
        {error, Reason} ->
            logger:warning("[llm_capability_retracted_v1_to_mesh] Failed to subscribe: ~p", [Reason]),
            {ok, #state{subscription_id = undefined}}
    end.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = EventType, data = EventData}}, State) ->
    %% Project to mesh (publish integration fact)
    logger:info("[llm_capability_retracted_v1_to_mesh] Publishing to mesh: ~p", [EventType]),
    hecate_mesh_publisher:publish_event(EventType, EventData),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_id = SubId}) ->
    case SubId of
        undefined -> ok;
        _ -> reckon_evoq_adapter:unsubscribe(serve_llm_store, SubId)
    end.
