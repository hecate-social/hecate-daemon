%%% @doc llm_capability_announced_v1 event
%%% Emitted when an LLM model capability is successfully announced.
-module(llm_capability_announced_v1).

-export([new/5, to_map/1, from_map/1]).
-export([get_model_name/1, get_agent_id/1, get_capability_mri/1,
         get_model_info/1, get_hardware_info/1, get_metadata/1, get_announced_at/1]).

-record(llm_capability_announced_v1, {
    model_name :: binary(),
    agent_identity :: binary(),
    capability_mri :: binary(),
    model_info :: map(),
    hardware_info :: map(),
    metadata :: map(),
    announced_at :: integer()
}).

-export_type([llm_capability_announced_v1/0]).
-opaque llm_capability_announced_v1() :: #llm_capability_announced_v1{}.

%% @doc Create a new llm_capability_announced_v1 event
-spec new(binary(), binary(), binary(), map(), map()) -> llm_capability_announced_v1().
new(ModelName, AgentID, CapabilityMRI, ModelInfo, HardwareInfo) ->
    #llm_capability_announced_v1{
        model_name = ModelName,
        agent_identity = AgentID,
        capability_mri = CapabilityMRI,
        model_info = ModelInfo,
        hardware_info = HardwareInfo,
        metadata = #{},
        announced_at = erlang:system_time(millisecond)
    }.

%% @doc Convert event to map for serialization
-spec to_map(llm_capability_announced_v1()) -> map().
to_map(#llm_capability_announced_v1{
    model_name = ModelName,
    agent_identity = AgentID,
    capability_mri = CapabilityMRI,
    model_info = ModelInfo,
    hardware_info = HardwareInfo,
    metadata = Metadata,
    announced_at = At
}) ->
    #{
        event_type => <<"llm_capability_announced_v1">>,
        model_name => ModelName,
        agent_identity => AgentID,
        capability_mri => CapabilityMRI,
        model_info => ModelInfo,
        hardware_info => HardwareInfo,
        metadata => Metadata,
        announced_at => At
    }.

%% @doc Create event from map (deserialization)
-spec from_map(map()) -> {ok, llm_capability_announced_v1()} | {error, term()}.
from_map(#{
    model_name := ModelName,
    agent_identity := AgentID,
    capability_mri := CapabilityMRI,
    announced_at := At
} = Map) ->
    {ok, #llm_capability_announced_v1{
        model_name = ModelName,
        agent_identity = AgentID,
        capability_mri = CapabilityMRI,
        model_info = maps:get(model_info, Map, #{}),
        hardware_info = maps:get(hardware_info, Map, #{}),
        metadata = maps:get(metadata, Map, #{}),
        announced_at = At
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessor functions
get_model_name(#llm_capability_announced_v1{model_name = N}) -> N.
get_agent_id(#llm_capability_announced_v1{agent_identity = ID}) -> ID.
get_capability_mri(#llm_capability_announced_v1{capability_mri = MRI}) -> MRI.
get_model_info(#llm_capability_announced_v1{model_info = M}) -> M.
get_hardware_info(#llm_capability_announced_v1{hardware_info = H}) -> H.
get_metadata(#llm_capability_announced_v1{metadata = M}) -> M.
get_announced_at(#llm_capability_announced_v1{announced_at = At}) -> At.
