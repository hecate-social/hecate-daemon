%%% @doc announce_capability_v1 command
%%% Announces a new capability to the mesh.
-module(announce_capability_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_mri/1, get_agent_id/1, get_tags/1, get_description/1,
         get_demo_procedure/1, get_metadata/1, get_announced_at/1]).

-record(announce_capability_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    tags :: [binary()],
    description :: binary(),
    demo_procedure :: binary() | undefined,
    metadata :: map()
}).

-export_type([announce_capability_v1/0]).
-opaque announce_capability_v1() :: #announce_capability_v1{}.

%% Suppress dialyzer supertype warnings (map param is more general than required keys)
-dialyzer({nowarn_function, [new/1, from_map/1]}).

%% @doc Create a new announce_capability_v1 command
-spec new(map()) -> {ok, announce_capability_v1()} | {error, invalid_mri | invalid_command}.
new(#{
    capability_mri := MRI,
    agent_identity := AgentID,
    tags := Tags,
    description := Desc
} = Params) ->
    Cmd = #announce_capability_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        tags = Tags,
        description = Desc,
        demo_procedure = maps:get(demo_procedure, Params, undefined),
        metadata = maps:get(metadata, Params, #{})
    },
    validate(Cmd).

%% @doc Validate command
-spec validate(announce_capability_v1()) -> {ok, announce_capability_v1()} | {error, invalid_mri | invalid_command}.
validate(#announce_capability_v1{capability_mri = MRI} = Cmd) when is_binary(MRI) ->
    case validate_mri(MRI) of
        ok -> {ok, Cmd};
        Error -> Error
    end;
validate(_) ->
    {error, invalid_command}.

%% @doc Convert to map
-spec to_map(announce_capability_v1()) -> map().
to_map(#announce_capability_v1{} = Cmd) ->
    #{
        capability_mri => get_mri(Cmd),
        agent_identity => get_agent_id(Cmd),
        tags => get_tags(Cmd),
        description => get_description(Cmd),
        demo_procedure => get_demo_procedure(Cmd),
        metadata => get_metadata(Cmd)
    }.

%% @doc Create command from map (for evoq integration)
-spec from_map(map()) -> {ok, announce_capability_v1()} | {error, invalid_mri | invalid_command}.
from_map(Map) ->
    new(Map).

%% Accessor functions
get_mri(#announce_capability_v1{capability_mri = MRI}) -> MRI.
get_agent_id(#announce_capability_v1{agent_identity = ID}) -> ID.
get_tags(#announce_capability_v1{tags = Tags}) -> Tags.
get_description(#announce_capability_v1{description = D}) -> D.
get_demo_procedure(#announce_capability_v1{demo_procedure = P}) -> P.
get_metadata(#announce_capability_v1{metadata = M}) -> M.

%% Get timestamp (extract from metadata for command ID generation)
get_announced_at(#announce_capability_v1{metadata = M}) ->
    maps:get(announced_at, M, erlang:system_time(millisecond)).

%% @private
validate_mri(<<"mri:capability:", _Rest/binary>>) -> ok;
validate_mri(_) -> {error, invalid_mri}.
