%%% @doc project_initiated_v1 event
%%% Emitted when a project is successfully initiated.
-module(project_initiated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_project_id/1, get_name/1, get_description/1, get_initiated_at/1]).

-record(project_initiated_v1, {
    project_id   :: binary(),
    name         :: binary(),
    description  :: binary() | undefined,
    initiated_at :: integer()
}).

-export_type([project_initiated_v1/0]).
-opaque project_initiated_v1() :: #project_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> project_initiated_v1().
new(#{project_id := ProjectId, name := Name} = Params) ->
    #project_initiated_v1{
        project_id = ProjectId,
        name = Name,
        description = maps:get(description, Params, undefined),
        initiated_at = erlang:system_time(millisecond)
    }.

-spec to_map(project_initiated_v1()) -> map().
to_map(#project_initiated_v1{} = E) ->
    #{
        event_type => <<"project_initiated_v1">>,
        project_id => E#project_initiated_v1.project_id,
        name => E#project_initiated_v1.name,
        description => E#project_initiated_v1.description,
        initiated_at => E#project_initiated_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, project_initiated_v1()} | {error, term()}.
from_map(#{project_id := ProjectId, name := Name} = Map) ->
    {ok, #project_initiated_v1{
        project_id = ProjectId,
        name = Name,
        description = maps:get(description, Map, undefined),
        initiated_at = maps:get(initiated_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

%% Accessors
get_project_id(#project_initiated_v1{project_id = V}) -> V.
get_name(#project_initiated_v1{name = V}) -> V.
get_description(#project_initiated_v1{description = V}) -> V.
get_initiated_at(#project_initiated_v1{initiated_at = V}) -> V.
