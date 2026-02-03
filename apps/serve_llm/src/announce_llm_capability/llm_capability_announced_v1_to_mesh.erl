%%% @doc Mesh emitter: llm_capability_announced_v1 → Macula Mesh
%%% Projects LLM capability announcements to the mesh as integration facts.
%%% Builds rich FACT payload with model, hardware, and status information.
-module(llm_capability_announced_v1_to_mesh).
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
    %% Subscribe to llm_capability_announced_v1 events from serve_llm_store
    case reckon_evoq_adapter:subscribe(
        serve_llm_store,
        event_type,
        <<"llm_capability_announced_v1">>,
        <<"mesh_llm_capability_announced">>,
        #{start_from => 0, subscriber_pid => self()}
    ) of
        {ok, SubId} ->
            logger:info("[llm_capability_announced_v1_to_mesh] Subscribed to events"),
            {ok, #state{subscription_id = SubId}};
        {error, Reason} ->
            logger:warning("[llm_capability_announced_v1_to_mesh] Failed to subscribe: ~p", [Reason]),
            {ok, #state{subscription_id = undefined}}
    end.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = EventType, data = EventData}}, State) ->
    %% Build rich FACT payload for mesh
    Fact = build_mesh_fact(EventData),
    logger:info("[llm_capability_announced_v1_to_mesh] Publishing to mesh: ~p", [EventType]),
    hecate_mesh_publisher:publish_event(EventType, Fact),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_id = SubId}) ->
    case SubId of
        undefined -> ok;
        _ -> reckon_evoq_adapter:unsubscribe(serve_llm_store, SubId)
    end.

%% Internal

%% @doc Build the rich FACT payload for mesh publication
build_mesh_fact(EventData) ->
    MRI = maps:get(capability_mri, EventData, <<>>),
    ModelInfo = maps:get(model_info, EventData, #{}),
    HardwareInfo = maps:get(hardware_info, EventData, #{}),
    AnnouncedAt = maps:get(announced_at, EventData, erlang:system_time(millisecond)),

    #{
        mri => MRI,
        type => <<"llm">>,

        %% Model information
        model => #{
            name => maps:get(name, ModelInfo, maps:get(model_name, EventData, <<>>)),
            context_length => maps:get(context_length, ModelInfo, 4096),
            quantization => maps:get(quantization, ModelInfo, <<"unknown">>),
            parameter_count => maps:get(parameter_count, ModelInfo, <<"unknown">>),
            family => maps:get(family, ModelInfo, <<"unknown">>)
        },

        %% Hardware information
        hardware => #{
            ram_gb => maps:get(ram_gb, HardwareInfo, 0),
            cpu_cores => maps:get(cpu_cores, HardwareInfo, 0),
            gpu => maps:get(gpu, HardwareInfo, <<"none">>),
            gpu_vram_gb => maps:get(gpu_vram_gb, HardwareInfo, 0),
            storage_path => maps:get(storage_path, HardwareInfo, <<>>)
        },

        %% Initial status (will be updated by heartbeat FACTs)
        status => #{
            queue_depth => 0,
            avg_tokens_per_sec => 0.0,
            available => true
        },

        announced_at => AnnouncedAt
    }.
