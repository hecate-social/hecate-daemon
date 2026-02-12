%%% @doc maybe_retract_capability handler
%%% Business logic for retracting capabilities.
%%% Validates the command and dispatches via evoq.
-module(maybe_retract_capability).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, handle_from_map/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
%% and opaque type usage in dispatch/1 and handle/2
-dialyzer({nowarn_function, [dispatch/1, handle/2]}).

%% @doc Handle retract_capability from a plain map payload.
-spec handle_from_map(map()) -> {ok, [capability_retracted_v1:capability_retracted_v1()]} | {error, term()}.
handle_from_map(#{capability_mri := _MRI, agent_identity := _AgentID} = Payload) ->
    case retract_capability_v1:new(Payload) of
        {ok, Cmd} -> handle(Cmd);
        {error, Reason} -> {error, Reason}
    end.

%% @doc Handle retract_capability_v1 command (business logic only)
%% Validates MRI format and agent identity.
%% Note: Ownership check requires aggregate state - use handle/2 when state available.
-spec handle(retract_capability_v1:retract_capability_v1()) ->
    {ok, [capability_retracted_v1:capability_retracted_v1()]} |
    {error, invalid_mri | invalid_mri_type | invalid_agent_identity}.
handle(Cmd) ->
    MRI = retract_capability_v1:get_mri(Cmd),
    AgentID = retract_capability_v1:get_agent_id(Cmd),

    case validate_command(MRI, AgentID) of
        ok ->
            Event = create_event_from_command(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Handle retract_capability_v1 command with ownership check.
%% OwnerID is the agent_id from the current aggregate state.
-spec handle(retract_capability_v1:retract_capability_v1(), binary()) ->
    {ok, [capability_retracted_v1:capability_retracted_v1()]} |
    {error, invalid_mri | invalid_mri_type | invalid_agent_identity | not_owner}.
handle(Cmd, OwnerID) ->
    AgentID = retract_capability_v1:get_agent_id(Cmd),
    case capability_validation:is_owner(AgentID, OwnerID) of
        true ->
            handle(Cmd);
        false ->
            {error, not_owner}
    end.

%% @doc Validate command fields
-spec validate_command(binary(), binary()) ->
    ok | {error, invalid_mri | invalid_mri_type | invalid_agent_identity}.
validate_command(MRI, AgentID) ->
    case capability_validation:validate_mri(MRI) of
        ok ->
            capability_validation:validate_agent_identity(AgentID);
        Error ->
            Error
    end.

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(retract_capability_v1:retract_capability_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    MRI = retract_capability_v1:get_mri(Cmd),
    Timestamp = retract_capability_v1:get_retracted_at(Cmd),

    EvoqCmd = #evoq_command{
        command_type = retract_capability,
        aggregate_type = node_aggregate,
        aggregate_id = MRI,
        payload = retract_capability_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp}
    },

    Opts = #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal functions

create_event_from_command(Cmd) ->
    MRI = retract_capability_v1:get_mri(Cmd),
    AgentID = retract_capability_v1:get_agent_id(Cmd),
    Reason = retract_capability_v1:get_reason(Cmd),

    capability_retracted_v1:new(MRI, AgentID, Reason).
