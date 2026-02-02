%%% @doc update_capability_v1 command
%%% Updates an existing capability (tags, description, metadata).
-module(update_capability_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_mri/1, get_agent_id/1, get_tags/1, get_description/1,
         get_demo_procedure/1, get_metadata/1, get_updated_at/1]).

-record(update_capability_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    tags :: [binary()] | undefined,
    description :: binary() | undefined,
    demo_procedure :: binary() | undefined,
    metadata :: map() | undefined
}).

-export_type([update_capability_v1/0]).
-opaque update_capability_v1() :: #update_capability_v1{}.

%% @doc Create a new update_capability_v1 command
-spec new(map()) -> {ok, update_capability_v1()} | {error, missing_required_fields | invalid_mri | invalid_command | no_updates_provided}.
new(#{
    capability_mri := MRI,
    agent_identity := AgentID
} = Params) ->
    Cmd = #update_capability_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        tags = maps:get(tags, Params, undefined),
        description = maps:get(description, Params, undefined),
        demo_procedure = maps:get(demo_procedure, Params, undefined),
        metadata = maps:get(metadata, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

%% @doc Validate command (must have at least one field to update)
-spec validate(update_capability_v1()) -> {ok, update_capability_v1()} | {error, invalid_mri | invalid_command | no_updates_provided}.
validate(#update_capability_v1{capability_mri = MRI} = Cmd) when is_binary(MRI) ->
    case validate_mri(MRI) of
        ok -> validate_has_updates(Cmd);
        Error -> Error
    end;
validate(_) ->
    {error, invalid_command}.

validate_has_updates(#update_capability_v1{
    tags = undefined,
    description = undefined,
    demo_procedure = undefined,
    metadata = undefined
}) ->
    {error, no_updates_provided};
validate_has_updates(Cmd) ->
    {ok, Cmd}.

%% @doc Convert to map
-spec to_map(update_capability_v1()) -> map().
to_map(#update_capability_v1{
    capability_mri = MRI,
    agent_identity = AgentID,
    tags = Tags,
    description = Desc,
    demo_procedure = DemoProc,
    metadata = Meta
}) ->
    Base = #{
        command_type => <<"update_capability">>,
        capability_mri => MRI,
        agent_identity => AgentID
    },
    maybe_add(maybe_add(maybe_add(maybe_add(Base,
        tags, Tags),
        description, Desc),
        demo_procedure, DemoProc),
        metadata, Meta).

maybe_add(Map, _Key, undefined) -> Map;
maybe_add(Map, Key, Value) -> Map#{Key => Value}.

%% @doc Create command from map
-spec from_map(map()) -> {ok, update_capability_v1()} | {error, missing_required_fields | invalid_mri | invalid_command | no_updates_provided}.
from_map(Map) ->
    new(Map).

%% Accessor functions
get_mri(#update_capability_v1{capability_mri = MRI}) -> MRI.
get_agent_id(#update_capability_v1{agent_identity = ID}) -> ID.
get_tags(#update_capability_v1{tags = Tags}) -> Tags.
get_description(#update_capability_v1{description = D}) -> D.
get_demo_procedure(#update_capability_v1{demo_procedure = P}) -> P.
get_metadata(#update_capability_v1{metadata = M}) -> M.

%% Get timestamp from metadata
get_updated_at(#update_capability_v1{metadata = M}) when is_map(M) ->
    maps:get(updated_at, M, erlang:system_time(millisecond));
get_updated_at(_) ->
    erlang:system_time(millisecond).

%% @private
validate_mri(<<"mri:capability:", _Rest/binary>>) -> ok;
validate_mri(_) -> {error, invalid_mri}.
