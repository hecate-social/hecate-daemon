%%% @doc Process Manager: On LLM Detected, Announce Capability
%%% Subscribes to llm_detected_v1 events from serve_llm domain.
%%% Dispatches announce_capability_v1 commands to manage_capabilities.
-module(on_llm_detected_announce_capability).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [subscribe_to_llm_events/0]}).

-record(state, {
    subscription_ref :: reference() | undefined,
    agent_identity :: binary()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    AgentIdentity = get_agent_identity(),
    %% Subscribe to serve_llm events
    self() ! subscribe,
    {ok, #state{subscription_ref = undefined, agent_identity = AgentIdentity}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    %% Subscribe to llm events from serve_llm_store
    SubRef = subscribe_to_llm_events(),
    {noreply, State#state{subscription_ref = SubRef}};
handle_info({event, #evoq_event{event_type = EventType, data = EventData}}, #state{agent_identity = AgentId} = State) ->
    handle_event(EventType, EventData, AgentId),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% Internal

subscribe_to_llm_events() ->
    case reckon_evoq_adapter:subscribe(
        serve_llm_store,
        stream,
        <<"llms">>,
        <<"on_llm_detected_announce_capability">>,
        #{start_from => 0, subscriber_pid => self()}
    ) of
        {ok, SubRef} -> SubRef;
        {error, _} -> undefined
    end.

handle_event(<<"llm_detected_v1">>, EventData, AgentIdentity) ->
    %% Convert LLM detection to capability announcement
    ModelName = maps:get(model_name, EventData, maps:get(<<"model_name">>, EventData, <<"unknown">>)),
    ModelInfo = maps:get(model_info, EventData, maps:get(<<"model_info">>, EventData, #{})),

    %% Build capability MRI from model name
    CapabilityMRI = build_capability_mri(ModelName),

    %% Read hardware info from hecate app config
    Hardware = get_hardware_info(),

    %% Build model metadata per QUEUE spec
    Model = #{
        name => ModelName,
        context_length => maps:get(context_length, ModelInfo, maps:get(<<"context_length">>, ModelInfo, 4096)),
        quantization => maps:get(quantization, ModelInfo, maps:get(<<"quantization">>, ModelInfo, <<"unknown">>)),
        parameter_count => maps:get(parameter_count, ModelInfo, maps:get(<<"parameter_count">>, ModelInfo, <<"unknown">>)),
        family => maps:get(family, ModelInfo, maps:get(<<"family">>, ModelInfo, <<"unknown">>)),
        size_bytes => maps:get(size_bytes, ModelInfo, maps:get(<<"size_bytes">>, ModelInfo, 0))
    },

    %% Build tags from model family
    Family = maps:get(family, Model),
    Tags = build_tags(Family),

    %% Build capability announcement command with rich metadata
    CmdParams = #{
        capability_mri => CapabilityMRI,
        agent_identity => AgentIdentity,
        tags => Tags,
        description => build_description(ModelName, ModelInfo),
        metadata => #{
            type => <<"llm">>,
            model => Model,
            hardware => Hardware,
            status => #{
                queue_depth => 0,
                avg_tokens_per_sec => 0.0,
                available => true
            }
        }
    },

    dispatch_announce_capability(CmdParams);
handle_event(_, _, _) ->
    %% Ignore other events
    ok.

build_capability_mri(ModelName) ->
    %% Sanitize model name for MRI (remove special chars)
    SafeName = sanitize_for_mri(ModelName),
    <<"mri:capability:llm/", SafeName/binary>>.

sanitize_for_mri(Name) when is_binary(Name) ->
    %% Replace : with - for MRI compatibility
    binary:replace(Name, <<":">>, <<"-">>, [global]).

build_description(ModelName, ModelInfo) ->
    Family = maps:get(family, ModelInfo, maps:get(<<"family">>, ModelInfo, <<"unknown">>)),
    ContextLen = maps:get(context_length, ModelInfo, maps:get(<<"context_length">>, ModelInfo, 4096)),
    iolist_to_binary(io_lib:format(
        "LLM capability: ~s (~s family, ~p context)",
        [ModelName, Family, ContextLen]
    )).

dispatch_announce_capability(CmdParams) ->
    case announce_capability_v1:new(CmdParams) of
        {ok, Cmd} ->
            %% Dispatch to manage_capabilities via evoq
            case maybe_announce_capability:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:info("[PM] Announced capability for LLM: ~p", [maps:get(capability_mri, CmdParams)]);
                {error, Reason} ->
                    logger:warning("[PM] Failed to announce capability: ~p", [Reason])
            end;
        {error, Reason} ->
            logger:warning("[PM] Invalid announce command: ~p", [Reason])
    end.

get_agent_identity() ->
    application:get_env(hecate, gateway_identity, <<"mri:agent:io.macula/hecate">>).

get_hardware_info() ->
    Default = #{
        ram_gb => 0,
        cpu_cores => 0,
        gpu => <<"none">>,
        gpu_vram_gb => 0,
        storage_path => <<"unknown">>
    },
    application:get_env(hecate, hardware, Default).

build_tags(Family) when is_binary(Family) ->
    BaseTags = [<<"llm">>, <<"chat">>, <<"ai">>],
    FamilyTag = string:lowercase(Family),
    case is_code_model(FamilyTag) of
        true -> [<<"code">> | BaseTags];
        false -> BaseTags
    end;
build_tags(_) ->
    [<<"llm">>, <<"chat">>, <<"ai">>].

is_code_model(Family) ->
    CodeFamilies = [<<"qwen2.5-coder">>, <<"codellama">>, <<"codegemma">>,
                    <<"starcoder">>, <<"deepseek-coder">>],
    lists:any(fun(CF) -> binary:match(Family, CF) =/= nomatch end, CodeFamilies).
