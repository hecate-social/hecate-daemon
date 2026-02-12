%%% @doc capability_retracted_v1 event
%%% Emitted when a capability is successfully retracted from the mesh.
-module(capability_retracted_v1).

-export([new/3, to_map/1, from_map/1]).
-export([get_mri/1, get_agent_id/1, get_reason/1, get_retracted_at/1]).

-record(capability_retracted_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    reason :: binary() | undefined,
    retracted_at :: integer()
}).

-export_type([capability_retracted_v1/0]).
-opaque capability_retracted_v1() :: #capability_retracted_v1{}.

%% @doc Create a new capability_retracted_v1 event
-spec new(binary(), binary(), binary() | undefined) -> capability_retracted_v1().
new(MRI, AgentID, Reason) ->
    #capability_retracted_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        reason = Reason,
        retracted_at = erlang:system_time(millisecond)
    }.

%% @doc Convert event to map for serialization
-spec to_map(capability_retracted_v1()) -> map().
to_map(#capability_retracted_v1{
    capability_mri = MRI,
    agent_identity = AgentID,
    reason = Reason,
    retracted_at = At
}) ->
    Base = #{
        event_type => <<"capability_retracted_v1">>,
        capability_mri => MRI,
        agent_identity => AgentID,
        retracted_at => At
    },
    case Reason of
        undefined -> Base;
        _ -> Base#{reason => Reason}
    end.

%% @doc Create event from map (deserialization)
-spec from_map(map()) -> {ok, capability_retracted_v1()} | {error, term()}.
from_map(#{
    capability_mri := MRI,
    agent_identity := AgentID,
    retracted_at := At
} = Map) ->
    {ok, #capability_retracted_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        reason = maps:get(reason, Map, undefined),
        retracted_at = At
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessor functions
get_mri(#capability_retracted_v1{capability_mri = MRI}) -> MRI.
get_agent_id(#capability_retracted_v1{agent_identity = ID}) -> ID.
get_reason(#capability_retracted_v1{reason = R}) -> R.
get_retracted_at(#capability_retracted_v1{retracted_at = At}) -> At.
