%%% @doc capability_announced_v1 event
%%% Emitted when a capability is successfully announced to the mesh.
-module(capability_announced_v1).

-export([new/6, to_map/1, from_map/1]).
-export([get_mri/1, get_agent_id/1, get_tags/1, get_description/1,
         get_demo_procedure/1, get_metadata/1, get_announced_at/1]).

-record(capability_announced_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    tags :: [binary()],
    description :: binary(),
    demo_procedure :: binary() | undefined,
    metadata :: map(),
    announced_at :: integer()
}).

-export_type([capability_announced_v1/0]).
-opaque capability_announced_v1() :: #capability_announced_v1{}.

%% @doc Create a new capability_announced_v1 event
-spec new(binary(), binary(), [binary()], binary(), binary() | undefined, map()) ->
    capability_announced_v1().
new(MRI, AgentID, Tags, Desc, DemoProc, Metadata) ->
    #capability_announced_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        tags = Tags,
        description = Desc,
        demo_procedure = DemoProc,
        metadata = Metadata,
        announced_at = erlang:system_time(millisecond)
    }.

%% @doc Convert event to map for serialization
-spec to_map(capability_announced_v1()) -> map().
to_map(#capability_announced_v1{
    capability_mri = MRI,
    agent_identity = AgentID,
    tags = Tags,
    description = Desc,
    demo_procedure = DemoProc,
    metadata = Metadata,
    announced_at = At
}) ->
    #{
        event_type => <<"capability_announced_v1">>,
        capability_mri => MRI,
        agent_identity => AgentID,
        tags => Tags,
        description => Desc,
        demo_procedure => DemoProc,
        metadata => Metadata,
        announced_at => At
    }.

%% @doc Create event from map (deserialization)
-spec from_map(map()) -> {ok, capability_announced_v1()} | {error, term()}.
from_map(#{
    capability_mri := MRI,
    agent_identity := AgentID,
    tags := Tags,
    description := Desc,
    announced_at := At
} = Map) ->
    {ok, #capability_announced_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        tags = Tags,
        description = Desc,
        demo_procedure = maps:get(demo_procedure, Map, undefined),
        metadata = maps:get(metadata, Map, #{}),
        announced_at = At
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessor functions
get_mri(#capability_announced_v1{capability_mri = MRI}) -> MRI.
get_agent_id(#capability_announced_v1{agent_identity = ID}) -> ID.
get_tags(#capability_announced_v1{tags = Tags}) -> Tags.
get_description(#capability_announced_v1{description = D}) -> D.
get_demo_procedure(#capability_announced_v1{demo_procedure = P}) -> P.
get_metadata(#capability_announced_v1{metadata = M}) -> M.
get_announced_at(#capability_announced_v1{announced_at = At}) -> At.
