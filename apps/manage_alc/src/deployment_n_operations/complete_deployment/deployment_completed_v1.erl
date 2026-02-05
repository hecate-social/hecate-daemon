%%% @doc deployment_completed_v1 event
%%% Emitted when the deployment and operations phase completes.
-module(deployment_completed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_completed_at/1]).

-record(deployment_completed_v1, {
    project_id   :: binary(),
    completed_at :: integer()
}).

-export_type([deployment_completed_v1/0]).
-opaque deployment_completed_v1() :: #deployment_completed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> deployment_completed_v1().
new(#{project_id := ProjectId} = _Params) ->
    #deployment_completed_v1{
        project_id = ProjectId,
        completed_at = erlang:system_time(millisecond)
    }.

-spec to_map(deployment_completed_v1()) -> map().
to_map(#deployment_completed_v1{} = E) ->
    #{
        event_type => <<"deployment_completed_v1">>,
        project_id => E#deployment_completed_v1.project_id,
        completed_at => E#deployment_completed_v1.completed_at
    }.

-spec from_map(map()) -> {ok, deployment_completed_v1()} | {error, term()}.
from_map(#{project_id := ProjectId} = Map) ->
    {ok, #deployment_completed_v1{
        project_id = ProjectId,
        completed_at = maps:get(completed_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#deployment_completed_v1{project_id = V}) -> V.
get_completed_at(#deployment_completed_v1{completed_at = V}) -> V.
