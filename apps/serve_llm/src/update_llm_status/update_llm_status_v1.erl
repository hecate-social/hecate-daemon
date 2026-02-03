%%% @doc update_llm_status_v1 command
%%% Updates the status of an LLM capability (queue depth, availability, etc.)
-module(update_llm_status_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_capability_mri/1, get_model_name/1, get_agent_id/1,
         get_queue_depth/1, get_avg_tokens_per_sec/1, get_available/1,
         get_metadata/1]).

-record(update_llm_status_v1, {
    capability_mri :: binary(),
    model_name :: binary(),
    agent_identity :: binary(),
    queue_depth :: non_neg_integer(),
    avg_tokens_per_sec :: float(),
    available :: boolean(),
    metadata :: map()
}).

-export_type([update_llm_status_v1/0]).
-opaque update_llm_status_v1() :: #update_llm_status_v1{}.

%% Suppress dialyzer supertype warnings
-dialyzer({nowarn_function, [new/1, from_map/1]}).

%% @doc Create a new update_llm_status_v1 command
-spec new(map()) -> {ok, update_llm_status_v1()} | {error, term()}.
new(#{
    capability_mri := CapabilityMRI,
    model_name := ModelName,
    agent_identity := AgentID
} = Params) ->
    Cmd = #update_llm_status_v1{
        capability_mri = CapabilityMRI,
        model_name = ModelName,
        agent_identity = AgentID,
        queue_depth = maps:get(queue_depth, Params, 0),
        avg_tokens_per_sec = maps:get(avg_tokens_per_sec, Params, 0.0),
        available = maps:get(available, Params, true),
        metadata = maps:get(metadata, Params, #{})
    },
    validate(Cmd).

%% @doc Validate command
-spec validate(update_llm_status_v1()) -> {ok, update_llm_status_v1()} | {error, term()}.
validate(#update_llm_status_v1{capability_mri = MRI} = Cmd)
  when is_binary(MRI), byte_size(MRI) > 0 ->
    {ok, Cmd};
validate(_) ->
    {error, invalid_command}.

%% @doc Convert to map
-spec to_map(update_llm_status_v1()) -> map().
to_map(#update_llm_status_v1{} = Cmd) ->
    #{
        capability_mri => get_capability_mri(Cmd),
        model_name => get_model_name(Cmd),
        agent_identity => get_agent_id(Cmd),
        queue_depth => get_queue_depth(Cmd),
        avg_tokens_per_sec => get_avg_tokens_per_sec(Cmd),
        available => get_available(Cmd),
        metadata => get_metadata(Cmd)
    }.

%% @doc Create command from map
-spec from_map(map()) -> {ok, update_llm_status_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessor functions
get_capability_mri(#update_llm_status_v1{capability_mri = MRI}) -> MRI.
get_model_name(#update_llm_status_v1{model_name = N}) -> N.
get_agent_id(#update_llm_status_v1{agent_identity = ID}) -> ID.
get_queue_depth(#update_llm_status_v1{queue_depth = Q}) -> Q.
get_avg_tokens_per_sec(#update_llm_status_v1{avg_tokens_per_sec = T}) -> T.
get_available(#update_llm_status_v1{available = A}) -> A.
get_metadata(#update_llm_status_v1{metadata = M}) -> M.
