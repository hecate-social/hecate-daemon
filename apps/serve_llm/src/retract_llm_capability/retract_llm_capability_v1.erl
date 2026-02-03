%%% @doc retract_llm_capability_v1 command
%%% Retracts an LLM model capability from the mesh (model went offline).
-module(retract_llm_capability_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_model_name/1, get_agent_id/1, get_capability_mri/1,
         get_reason/1, get_metadata/1, get_retracted_at/1]).

-record(retract_llm_capability_v1, {
    model_name :: binary(),
    agent_identity :: binary(),
    capability_mri :: binary(),
    reason :: binary(),           %% e.g., <<"model_removed">>, <<"backend_offline">>
    metadata :: map()
}).

-export_type([retract_llm_capability_v1/0]).
-opaque retract_llm_capability_v1() :: #retract_llm_capability_v1{}.

%% Suppress dialyzer supertype warnings
-dialyzer({nowarn_function, [new/1, from_map/1]}).

%% @doc Create a new retract_llm_capability_v1 command
-spec new(map()) -> {ok, retract_llm_capability_v1()} | {error, term()}.
new(#{
    model_name := ModelName,
    agent_identity := AgentID
} = Params) ->
    CapabilityMRI = build_capability_mri(AgentID, ModelName),
    Cmd = #retract_llm_capability_v1{
        model_name = ModelName,
        agent_identity = AgentID,
        capability_mri = CapabilityMRI,
        reason = maps:get(reason, Params, <<"model_removed">>),
        metadata = maps:get(metadata, Params, #{})
    },
    validate(Cmd).

%% @doc Validate command
-spec validate(retract_llm_capability_v1()) -> {ok, retract_llm_capability_v1()} | {error, term()}.
validate(#retract_llm_capability_v1{model_name = Name, agent_identity = Agent} = Cmd)
  when is_binary(Name), is_binary(Agent), byte_size(Name) > 0 ->
    {ok, Cmd};
validate(_) ->
    {error, invalid_command}.

%% @doc Convert to map
-spec to_map(retract_llm_capability_v1()) -> map().
to_map(#retract_llm_capability_v1{} = Cmd) ->
    #{
        model_name => get_model_name(Cmd),
        agent_identity => get_agent_id(Cmd),
        capability_mri => get_capability_mri(Cmd),
        reason => get_reason(Cmd),
        metadata => get_metadata(Cmd)
    }.

%% @doc Create command from map
-spec from_map(map()) -> {ok, retract_llm_capability_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessor functions
get_model_name(#retract_llm_capability_v1{model_name = N}) -> N.
get_agent_id(#retract_llm_capability_v1{agent_identity = ID}) -> ID.
get_capability_mri(#retract_llm_capability_v1{capability_mri = MRI}) -> MRI.
get_reason(#retract_llm_capability_v1{reason = R}) -> R.
get_metadata(#retract_llm_capability_v1{metadata = M}) -> M.

get_retracted_at(#retract_llm_capability_v1{metadata = M}) ->
    maps:get(retracted_at, M, erlang:system_time(millisecond)).

%% @private
build_capability_mri(AgentID, ModelName) ->
    case AgentID of
        <<"mri:agent:", Rest/binary>> ->
            SafeModelName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
            <<"mri:capability:", Rest/binary, "/llm/", SafeModelName/binary>>;
        _ ->
            SafeModelName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
            <<"mri:capability:io.macula/unknown/llm/", SafeModelName/binary>>
    end.
