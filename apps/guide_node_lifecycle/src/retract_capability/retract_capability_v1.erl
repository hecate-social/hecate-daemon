%%% @doc retract_capability_v1 command
%%% Retracts an existing capability from the mesh.
-module(retract_capability_v1).

-export([new/1, new/3, from_map/1, validate/1, to_map/1]).
-export([get_mri/1, get_agent_id/1, get_reason/1, get_retracted_at/1]).

-record(retract_capability_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    reason :: binary() | undefined
}).

-export_type([retract_capability_v1/0]).
-opaque retract_capability_v1() :: #retract_capability_v1{}.

%% @doc Create a new retract_capability_v1 command from map
-spec new(map()) -> {ok, retract_capability_v1()} | {error, missing_required_fields | invalid_mri | invalid_command}.
new(#{
    capability_mri := MRI,
    agent_identity := AgentID
} = Params) ->
    Cmd = #retract_capability_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        reason = maps:get(reason, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

%% @doc Create a new retract_capability_v1 command with explicit args
-spec new(binary(), binary(), binary() | undefined) ->
    {ok, retract_capability_v1()} | {error, invalid_mri | invalid_command}.
new(MRI, AgentID, Reason) ->
    Cmd = #retract_capability_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        reason = Reason
    },
    validate(Cmd).

%% @doc Validate command
-spec validate(retract_capability_v1()) -> {ok, retract_capability_v1()} | {error, invalid_mri | invalid_command}.
validate(#retract_capability_v1{capability_mri = MRI} = Cmd) when is_binary(MRI) ->
    case validate_mri(MRI) of
        ok -> {ok, Cmd};
        Error -> Error
    end;
validate(_) ->
    {error, invalid_command}.

%% @doc Convert to map
-spec to_map(retract_capability_v1()) -> map().
to_map(#retract_capability_v1{
    capability_mri = MRI,
    agent_identity = AgentID,
    reason = Reason
}) ->
    Base = #{
        command_type => <<"retract_capability">>,
        capability_mri => MRI,
        agent_identity => AgentID
    },
    case Reason of
        undefined -> Base;
        _ -> Base#{reason => Reason}
    end.

%% @doc Create command from map
-spec from_map(map()) -> {ok, retract_capability_v1()} | {error, missing_required_fields | invalid_mri | invalid_command}.
from_map(Map) ->
    new(Map).

%% Accessor functions
get_mri(#retract_capability_v1{capability_mri = MRI}) -> MRI.
get_agent_id(#retract_capability_v1{agent_identity = ID}) -> ID.
get_reason(#retract_capability_v1{reason = R}) -> R.

%% Get timestamp (for command ID generation)
get_retracted_at(_Cmd) ->
    erlang:system_time(millisecond).

%% @private
validate_mri(<<"mri:capability:", _Rest/binary>>) -> ok;
validate_mri(_) -> {error, invalid_mri}.
