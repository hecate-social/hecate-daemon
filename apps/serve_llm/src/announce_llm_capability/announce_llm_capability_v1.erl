%%% @doc announce_llm_capability_v1 command
%%% Announces an LLM model capability to the mesh with rich metadata.
-module(announce_llm_capability_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_model_name/1, get_agent_id/1, get_capability_mri/1,
         get_model_info/1, get_hardware_info/1, get_metadata/1, get_announced_at/1]).

-record(announce_llm_capability_v1, {
    model_name :: binary(),           %% e.g., <<"llama3.2:3b">>
    agent_identity :: binary(),       %% e.g., <<"mri:agent:io.macula/hecate-dev">>
    capability_mri :: binary(),       %% e.g., <<"mri:capability:io.macula/hecate-dev/llm/llama3.2-3b">>
    model_info :: map(),              %% context_length, quantization, parameter_count, family
    hardware_info :: map(),           %% ram_gb, cpu_cores, gpu, storage_path
    metadata :: map()
}).

-export_type([announce_llm_capability_v1/0]).
-opaque announce_llm_capability_v1() :: #announce_llm_capability_v1{}.

%% Suppress dialyzer supertype warnings
-dialyzer({nowarn_function, [new/1, from_map/1]}).

%% @doc Create a new announce_llm_capability_v1 command
-spec new(map()) -> {ok, announce_llm_capability_v1()} | {error, term()}.
new(#{
    model_name := ModelName,
    agent_identity := AgentID
} = Params) ->
    %% Build capability MRI from agent identity and model name
    CapabilityMRI = build_capability_mri(AgentID, ModelName),

    %% Build model info from params or Ollama response
    ModelInfo = build_model_info(Params),

    %% Get hardware info from params or config
    HardwareInfo = build_hardware_info(Params),

    Cmd = #announce_llm_capability_v1{
        model_name = ModelName,
        agent_identity = AgentID,
        capability_mri = CapabilityMRI,
        model_info = ModelInfo,
        hardware_info = HardwareInfo,
        metadata = maps:get(metadata, Params, #{})
    },
    validate(Cmd).

%% @doc Validate command
-spec validate(announce_llm_capability_v1()) -> {ok, announce_llm_capability_v1()} | {error, term()}.
validate(#announce_llm_capability_v1{model_name = Name, agent_identity = Agent} = Cmd)
  when is_binary(Name), is_binary(Agent), byte_size(Name) > 0 ->
    {ok, Cmd};
validate(_) ->
    {error, invalid_command}.

%% @doc Convert to map
-spec to_map(announce_llm_capability_v1()) -> map().
to_map(#announce_llm_capability_v1{} = Cmd) ->
    #{
        model_name => get_model_name(Cmd),
        agent_identity => get_agent_id(Cmd),
        capability_mri => get_capability_mri(Cmd),
        model_info => get_model_info(Cmd),
        hardware_info => get_hardware_info(Cmd),
        metadata => get_metadata(Cmd)
    }.

%% @doc Create command from map
-spec from_map(map()) -> {ok, announce_llm_capability_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessor functions
get_model_name(#announce_llm_capability_v1{model_name = N}) -> N.
get_agent_id(#announce_llm_capability_v1{agent_identity = ID}) -> ID.
get_capability_mri(#announce_llm_capability_v1{capability_mri = MRI}) -> MRI.
get_model_info(#announce_llm_capability_v1{model_info = M}) -> M.
get_hardware_info(#announce_llm_capability_v1{hardware_info = H}) -> H.
get_metadata(#announce_llm_capability_v1{metadata = M}) -> M.

get_announced_at(#announce_llm_capability_v1{metadata = M}) ->
    maps:get(announced_at, M, erlang:system_time(millisecond)).

%% @private Build capability MRI from agent identity and model name
build_capability_mri(AgentID, ModelName) ->
    case AgentID of
        <<"mri:agent:", Rest/binary>> ->
            SafeModelName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
            <<"mri:capability:", Rest/binary, "/llm/", SafeModelName/binary>>;
        _ ->
            SafeModelName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
            <<"mri:capability:io.macula/unknown/llm/", SafeModelName/binary>>
    end.

%% @private Build model info from params
build_model_info(Params) ->
    %% Check if model_info is directly provided
    case maps:get(model_info, Params, undefined) of
        undefined ->
            %% Build from individual fields (backward compatibility)
            #{
                name => maps:get(model_name, Params),
                context_length => maps:get(context_length, Params, 4096),
                quantization => maps:get(quantization, Params, <<"unknown">>),
                parameter_count => maps:get(parameter_count, Params, <<"unknown">>),
                family => maps:get(family, Params, <<"unknown">>),
                size_bytes => maps:get(model_size, Params, 0)
            };
        ModelInfo when is_map(ModelInfo) ->
            ModelInfo
    end.

%% @private Build hardware info from params or config
build_hardware_info(Params) ->
    case maps:get(hardware_info, Params, undefined) of
        undefined ->
            %% Read from application config
            get_hardware_config();
        HardwareInfo when is_map(HardwareInfo) ->
            HardwareInfo
    end.

%% @private Get hardware configuration
get_hardware_config() ->
    #{
        ram_gb => get_hardware_env(ram_gb, 16),
        cpu_cores => get_hardware_env(cpu_cores, 4),
        gpu => get_hardware_env(gpu, <<"none">>),
        gpu_vram_gb => get_hardware_env(gpu_vram_gb, 0),
        storage_path => get_hardware_env(storage_path, <<"/tmp">>)
    }.

get_hardware_env(Key, Default) ->
    case application:get_env(hardware, Key) of
        {ok, Value} -> ensure_binary_if_needed(Key, Value);
        undefined -> Default
    end.

ensure_binary_if_needed(gpu, V) when is_list(V) -> list_to_binary(V);
ensure_binary_if_needed(storage_path, V) when is_list(V) -> list_to_binary(V);
ensure_binary_if_needed(_, V) -> V.
