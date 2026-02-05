%%% @doc skeleton_created_v1 event
%%% Emitted when a skeleton is created during testing and implementation.
-module(skeleton_created_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_skeleton_id/1, get_description/1, get_created_at/1]).

-record(skeleton_created_v1, {
    project_id  :: binary(),
    skeleton_id :: binary(),
    description :: binary() | undefined,
    created_at  :: integer()
}).

-export_type([skeleton_created_v1/0]).
-opaque skeleton_created_v1() :: #skeleton_created_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> skeleton_created_v1().
new(#{project_id := ProjectId, skeleton_id := SkeletonId} = Params) ->
    #skeleton_created_v1{
        project_id = ProjectId,
        skeleton_id = SkeletonId,
        description = maps:get(description, Params, undefined),
        created_at = erlang:system_time(millisecond)
    }.

-spec to_map(skeleton_created_v1()) -> map().
to_map(#skeleton_created_v1{} = E) ->
    #{
        event_type => <<"skeleton_created_v1">>,
        project_id => E#skeleton_created_v1.project_id,
        skeleton_id => E#skeleton_created_v1.skeleton_id,
        description => E#skeleton_created_v1.description,
        created_at => E#skeleton_created_v1.created_at
    }.

-spec from_map(map()) -> {ok, skeleton_created_v1()} | {error, term()}.
from_map(#{project_id := ProjectId, skeleton_id := SkeletonId} = Map) ->
    {ok, #skeleton_created_v1{
        project_id = ProjectId,
        skeleton_id = SkeletonId,
        description = maps:get(description, Map, undefined),
        created_at = maps:get(created_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#skeleton_created_v1{project_id = V}) -> V.
get_skeleton_id(#skeleton_created_v1{skeleton_id = V}) -> V.
get_description(#skeleton_created_v1{description = V}) -> V.
get_created_at(#skeleton_created_v1{created_at = V}) -> V.
