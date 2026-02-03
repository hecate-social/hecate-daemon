%%% @doc llm_capability_retracted_v1 event
%%% Emitted when an LLM model capability is retracted from the mesh.
-module(llm_capability_retracted_v1).

-export([new/5, to_map/1, from_map/1]).
-export([get_model_name/1, get_agent_id/1, get_capability_mri/1,
         get_reason/1, get_metadata/1, get_retracted_at/1]).

-record(llm_capability_retracted_v1, {
    model_name :: binary(),
    agent_identity :: binary(),
    capability_mri :: binary(),
    reason :: binary(),
    metadata :: map(),
    retracted_at :: integer()
}).

-export_type([llm_capability_retracted_v1/0]).
-opaque llm_capability_retracted_v1() :: #llm_capability_retracted_v1{}.

%% @doc Create a new llm_capability_retracted_v1 event
-spec new(binary(), binary(), binary(), binary(), map()) ->
    llm_capability_retracted_v1().
new(ModelName, AgentID, CapabilityMRI, Reason, Metadata) ->
    #llm_capability_retracted_v1{
        model_name = ModelName,
        agent_identity = AgentID,
        capability_mri = CapabilityMRI,
        reason = Reason,
        metadata = Metadata,
        retracted_at = erlang:system_time(millisecond)
    }.

%% @doc Convert event to map for serialization
-spec to_map(llm_capability_retracted_v1()) -> map().
to_map(#llm_capability_retracted_v1{
    model_name = ModelName,
    agent_identity = AgentID,
    capability_mri = CapabilityMRI,
    reason = Reason,
    metadata = Metadata,
    retracted_at = At
}) ->
    #{
        event_type => <<"llm_capability_retracted_v1">>,
        model_name => ModelName,
        agent_identity => AgentID,
        capability_mri => CapabilityMRI,
        reason => Reason,
        metadata => Metadata,
        retracted_at => At
    }.

%% @doc Create event from map (deserialization)
-spec from_map(map()) -> {ok, llm_capability_retracted_v1()} | {error, term()}.
from_map(#{
    model_name := ModelName,
    agent_identity := AgentID,
    capability_mri := CapabilityMRI,
    retracted_at := At
} = Map) ->
    {ok, #llm_capability_retracted_v1{
        model_name = ModelName,
        agent_identity = AgentID,
        capability_mri = CapabilityMRI,
        reason = maps:get(reason, Map, <<"unknown">>),
        metadata = maps:get(metadata, Map, #{}),
        retracted_at = At
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessor functions
get_model_name(#llm_capability_retracted_v1{model_name = N}) -> N.
get_agent_id(#llm_capability_retracted_v1{agent_identity = ID}) -> ID.
get_capability_mri(#llm_capability_retracted_v1{capability_mri = MRI}) -> MRI.
get_reason(#llm_capability_retracted_v1{reason = R}) -> R.
get_metadata(#llm_capability_retracted_v1{metadata = M}) -> M.
get_retracted_at(#llm_capability_retracted_v1{retracted_at = At}) -> At.
