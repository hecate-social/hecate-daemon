%%% @doc maybe_update_capability handler
%%% Business logic for updating capabilities.
%%% Validates the command and dispatches via evoq.
-module(maybe_update_capability).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, handle_from_map/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
%% and opaque type usage in dispatch/1 and handle/2
-dialyzer({nowarn_function, [dispatch/1, handle/2]}).

%% @doc Handle update_capability from a plain map payload.
-spec handle_from_map(map()) -> {ok, [capability_updated_v1:capability_updated_v1()]} | {error, term()}.
handle_from_map(#{capability_mri := _MRI, agent_identity := _AgentID} = Payload) ->
    case update_capability_v1:new(Payload) of
        {ok, Cmd} -> handle(Cmd);
        {error, Reason} -> {error, Reason}
    end.

%% @doc Handle update_capability_v1 command (business logic only)
%% Validates MRI format, agent identity, and tags.
%% Note: Ownership check requires aggregate state - use handle/2 when state available.
-spec handle(update_capability_v1:update_capability_v1()) ->
    {ok, [capability_updated_v1:capability_updated_v1()]} |
    {error, invalid_mri | invalid_mri_type | invalid_agent_identity | invalid_tags}.
handle(Cmd) ->
    MRI = update_capability_v1:get_mri(Cmd),
    AgentID = update_capability_v1:get_agent_id(Cmd),
    Tags = update_capability_v1:get_tags(Cmd),

    case validate_command(MRI, AgentID, Tags) of
        ok ->
            Event = create_event_from_command(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Handle update_capability_v1 command with ownership check.
%% OwnerID is the agent_id from the current aggregate state.
-spec handle(update_capability_v1:update_capability_v1(), binary()) ->
    {ok, [capability_updated_v1:capability_updated_v1()]} |
    {error, invalid_mri | invalid_mri_type | invalid_agent_identity | invalid_tags | not_owner}.
handle(Cmd, OwnerID) ->
    AgentID = update_capability_v1:get_agent_id(Cmd),
    case capability_validation:is_owner(AgentID, OwnerID) of
        true ->
            handle(Cmd);
        false ->
            {error, not_owner}
    end.

%% @doc Validate command fields
-spec validate_command(binary(), binary(), [binary()]) ->
    ok | {error, invalid_mri | invalid_mri_type | invalid_agent_identity | invalid_tags}.
validate_command(MRI, AgentID, Tags) ->
    case capability_validation:validate_mri(MRI) of
        ok ->
            case capability_validation:validate_agent_identity(AgentID) of
                ok ->
                    capability_validation:validate_tags(Tags);
                Error ->
                    Error
            end;
        Error ->
            Error
    end.

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(update_capability_v1:update_capability_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    MRI = update_capability_v1:get_mri(Cmd),
    Timestamp = update_capability_v1:get_updated_at(Cmd),

    EvoqCmd = #evoq_command{
        command_type = update_capability,
        aggregate_type = node_aggregate,
        aggregate_id = MRI,
        payload = update_capability_v1:to_map(Cmd),
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
    MRI = update_capability_v1:get_mri(Cmd),
    AgentID = update_capability_v1:get_agent_id(Cmd),
    Tags = update_capability_v1:get_tags(Cmd),
    Desc = update_capability_v1:get_description(Cmd),
    DemoProc = update_capability_v1:get_demo_procedure(Cmd),
    Metadata = update_capability_v1:get_metadata(Cmd),

    capability_updated_v1:new(MRI, AgentID, Tags, Desc, DemoProc, Metadata).
