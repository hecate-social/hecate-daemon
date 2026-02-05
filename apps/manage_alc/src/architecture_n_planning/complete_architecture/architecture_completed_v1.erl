%%% @doc architecture_completed_v1 event
%%% Emitted when the architecture and planning phase is completed for a project.
-module(architecture_completed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_completed_at/1]).

-record(architecture_completed_v1, {
    project_id   :: binary(),
    completed_at :: integer()
}).

-export_type([architecture_completed_v1/0]).
-opaque architecture_completed_v1() :: #architecture_completed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> architecture_completed_v1().
new(#{project_id := ProjectId} = _Params) ->
    #architecture_completed_v1{
        project_id = ProjectId,
        completed_at = erlang:system_time(millisecond)
    }.

-spec to_map(architecture_completed_v1()) -> map().
to_map(#architecture_completed_v1{} = E) ->
    #{
        event_type => <<"architecture_completed_v1">>,
        project_id => E#architecture_completed_v1.project_id,
        completed_at => E#architecture_completed_v1.completed_at
    }.

-spec from_map(map()) -> {ok, architecture_completed_v1()} | {error, term()}.
from_map(#{project_id := ProjectId} = Map) ->
    {ok, #architecture_completed_v1{
        project_id = ProjectId,
        completed_at = maps:get(completed_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#architecture_completed_v1{project_id = V}) -> V.
get_completed_at(#architecture_completed_v1{completed_at = V}) -> V.
