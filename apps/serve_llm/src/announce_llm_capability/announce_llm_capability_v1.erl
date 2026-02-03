%%% @doc announce_llm_capability_v1 command
%%% Announces an LLM model capability to the mesh.
-module(announce_llm_capability_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_model_name/1, get_agent_id/1, get_capability_mri/1,
         get_model_size/1, get_quantization/1, get_context_length/1,
         get_metadata/1, get_announced_at/1]).

-record(announce_llm_capability_v1, {
    model_name :: binary(),           %% e.g., <<"llama3.2">>
    agent_identity :: binary(),       %% e.g., <<"mri:agent:io.macula/hecate-dev">>
    capability_mri :: binary(),       %% e.g., <<"mri:capability:io.macula/hecate-dev/llm/llama3.2">>
    model_size :: integer(),          %% Size in bytes
    quantization :: binary() | undefined,  %% e.g., <<"Q4_K_M">>
    context_length :: integer(),      %% Max context window
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
    Cmd = #announce_llm_capability_v1{
        model_name = ModelName,
        agent_identity = AgentID,
        capability_mri = CapabilityMRI,
        model_size = maps:get(model_size, Params, 0),
        quantization = maps:get(quantization, Params, undefined),
        context_length = maps:get(context_length, Params, 4096),
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
        model_size => get_model_size(Cmd),
        quantization => get_quantization(Cmd),
        context_length => get_context_length(Cmd),
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
get_model_size(#announce_llm_capability_v1{model_size = S}) -> S.
get_quantization(#announce_llm_capability_v1{quantization = Q}) -> Q.
get_context_length(#announce_llm_capability_v1{context_length = C}) -> C.
get_metadata(#announce_llm_capability_v1{metadata = M}) -> M.

get_announced_at(#announce_llm_capability_v1{metadata = M}) ->
    maps:get(announced_at, M, erlang:system_time(millisecond)).

%% @private Build capability MRI from agent identity and model name
build_capability_mri(AgentID, ModelName) ->
    %% Extract realm and agent path from agent MRI
    %% mri:agent:io.macula/hecate-dev → mri:capability:io.macula/hecate-dev/llm/llama3.2
    case AgentID of
        <<"mri:agent:", Rest/binary>> ->
            %% Sanitize model name (replace : with -)
            SafeModelName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
            <<"mri:capability:", Rest/binary, "/llm/", SafeModelName/binary>>;
        _ ->
            %% Fallback for non-MRI identities
            SafeModelName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
            <<"mri:capability:io.macula/unknown/llm/", SafeModelName/binary>>
    end.
