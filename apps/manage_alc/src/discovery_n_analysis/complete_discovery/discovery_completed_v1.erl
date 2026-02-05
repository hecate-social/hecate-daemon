%%% @doc discovery_completed_v1 event
%%% Emitted when the discovery phase is completed for a project.
-module(discovery_completed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_completed_at/1]).

-record(discovery_completed_v1, {
    project_id   :: binary(),
    completed_at :: integer()
}).

-export_type([discovery_completed_v1/0]).
-opaque discovery_completed_v1() :: #discovery_completed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> discovery_completed_v1().
new(#{project_id := ProjectId} = _Params) ->
    #discovery_completed_v1{
        project_id = ProjectId,
        completed_at = erlang:system_time(millisecond)
    }.

-spec to_map(discovery_completed_v1()) -> map().
to_map(#discovery_completed_v1{} = E) ->
    #{
        event_type => <<"discovery_completed_v1">>,
        project_id => E#discovery_completed_v1.project_id,
        completed_at => E#discovery_completed_v1.completed_at
    }.

-spec from_map(map()) -> {ok, discovery_completed_v1()} | {error, term()}.
from_map(#{project_id := ProjectId} = Map) ->
    {ok, #discovery_completed_v1{
        project_id = ProjectId,
        completed_at = maps:get(completed_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#discovery_completed_v1{project_id = V}) -> V.
get_completed_at(#discovery_completed_v1{completed_at = V}) -> V.
