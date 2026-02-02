%%% @doc capability_updated_v1 event
%%% Emitted when a capability is successfully updated.
-module(capability_updated_v1).

-export([new/6, to_map/1, from_map/1]).
-export([get_mri/1, get_agent_id/1, get_tags/1, get_description/1,
         get_demo_procedure/1, get_metadata/1, get_updated_at/1]).

-record(capability_updated_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    tags :: [binary()] | undefined,
    description :: binary() | undefined,
    demo_procedure :: binary() | undefined,
    metadata :: map() | undefined,
    updated_at :: integer()
}).

-export_type([capability_updated_v1/0]).
-opaque capability_updated_v1() :: #capability_updated_v1{}.

%% @doc Create a new capability_updated_v1 event
-spec new(binary(), binary(), [binary()] | undefined, binary() | undefined,
          binary() | undefined, map() | undefined) -> capability_updated_v1().
new(MRI, AgentID, Tags, Desc, DemoProc, Metadata) ->
    #capability_updated_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        tags = Tags,
        description = Desc,
        demo_procedure = DemoProc,
        metadata = Metadata,
        updated_at = erlang:system_time(millisecond)
    }.

%% @doc Convert event to map for serialization
-spec to_map(capability_updated_v1()) -> map().
to_map(#capability_updated_v1{
    capability_mri = MRI,
    agent_identity = AgentID,
    tags = Tags,
    description = Desc,
    demo_procedure = DemoProc,
    metadata = Metadata,
    updated_at = At
}) ->
    Base = #{
        event_type => <<"capability_updated_v1">>,
        capability_mri => MRI,
        agent_identity => AgentID,
        updated_at => At
    },
    maybe_add(maybe_add(maybe_add(maybe_add(Base,
        tags, Tags),
        description, Desc),
        demo_procedure, DemoProc),
        metadata, Metadata).

maybe_add(Map, _Key, undefined) -> Map;
maybe_add(Map, Key, Value) -> Map#{Key => Value}.

%% @doc Create event from map (deserialization)
-spec from_map(map()) -> {ok, capability_updated_v1()} | {error, term()}.
from_map(#{
    capability_mri := MRI,
    agent_identity := AgentID,
    updated_at := At
} = Map) ->
    {ok, #capability_updated_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        tags = maps:get(tags, Map, undefined),
        description = maps:get(description, Map, undefined),
        demo_procedure = maps:get(demo_procedure, Map, undefined),
        metadata = maps:get(metadata, Map, undefined),
        updated_at = At
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessor functions
get_mri(#capability_updated_v1{capability_mri = MRI}) -> MRI.
get_agent_id(#capability_updated_v1{agent_identity = ID}) -> ID.
get_tags(#capability_updated_v1{tags = Tags}) -> Tags.
get_description(#capability_updated_v1{description = D}) -> D.
get_demo_procedure(#capability_updated_v1{demo_procedure = P}) -> P.
get_metadata(#capability_updated_v1{metadata = M}) -> M.
get_updated_at(#capability_updated_v1{updated_at = At}) -> At.
