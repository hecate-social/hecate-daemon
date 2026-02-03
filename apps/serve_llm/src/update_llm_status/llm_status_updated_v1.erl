%%% @doc llm_status_updated_v1 event
%%% Emitted when an LLM capability's status is updated (heartbeat).
-module(llm_status_updated_v1).

-export([new/6, to_map/1, from_map/1]).
-export([get_capability_mri/1, get_model_name/1, get_agent_id/1,
         get_queue_depth/1, get_avg_tokens_per_sec/1, get_available/1,
         get_updated_at/1]).

-record(llm_status_updated_v1, {
    capability_mri :: binary(),
    model_name :: binary(),
    agent_identity :: binary(),
    queue_depth :: non_neg_integer(),
    avg_tokens_per_sec :: float(),
    available :: boolean(),
    updated_at :: integer()
}).

-export_type([llm_status_updated_v1/0]).
-opaque llm_status_updated_v1() :: #llm_status_updated_v1{}.

%% @doc Create a new llm_status_updated_v1 event
-spec new(binary(), binary(), binary(), non_neg_integer(), float(), boolean()) ->
    llm_status_updated_v1().
new(CapabilityMRI, ModelName, AgentID, QueueDepth, AvgTokensPerSec, Available) ->
    #llm_status_updated_v1{
        capability_mri = CapabilityMRI,
        model_name = ModelName,
        agent_identity = AgentID,
        queue_depth = QueueDepth,
        avg_tokens_per_sec = AvgTokensPerSec,
        available = Available,
        updated_at = erlang:system_time(millisecond)
    }.

%% @doc Convert event to map for serialization
-spec to_map(llm_status_updated_v1()) -> map().
to_map(#llm_status_updated_v1{
    capability_mri = CapabilityMRI,
    model_name = ModelName,
    agent_identity = AgentID,
    queue_depth = QueueDepth,
    avg_tokens_per_sec = AvgTokensPerSec,
    available = Available,
    updated_at = At
}) ->
    #{
        event_type => <<"llm_status_updated_v1">>,
        capability_mri => CapabilityMRI,
        model_name => ModelName,
        agent_identity => AgentID,
        queue_depth => QueueDepth,
        avg_tokens_per_sec => AvgTokensPerSec,
        available => Available,
        updated_at => At
    }.

%% @doc Create event from map (deserialization)
-spec from_map(map()) -> {ok, llm_status_updated_v1()} | {error, term()}.
from_map(#{
    capability_mri := CapabilityMRI,
    model_name := ModelName,
    agent_identity := AgentID,
    updated_at := At
} = Map) ->
    {ok, #llm_status_updated_v1{
        capability_mri = CapabilityMRI,
        model_name = ModelName,
        agent_identity = AgentID,
        queue_depth = maps:get(queue_depth, Map, 0),
        avg_tokens_per_sec = maps:get(avg_tokens_per_sec, Map, 0.0),
        available = maps:get(available, Map, true),
        updated_at = At
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessor functions
get_capability_mri(#llm_status_updated_v1{capability_mri = MRI}) -> MRI.
get_model_name(#llm_status_updated_v1{model_name = N}) -> N.
get_agent_id(#llm_status_updated_v1{agent_identity = ID}) -> ID.
get_queue_depth(#llm_status_updated_v1{queue_depth = Q}) -> Q.
get_avg_tokens_per_sec(#llm_status_updated_v1{avg_tokens_per_sec = T}) -> T.
get_available(#llm_status_updated_v1{available = A}) -> A.
get_updated_at(#llm_status_updated_v1{updated_at = At}) -> At.
