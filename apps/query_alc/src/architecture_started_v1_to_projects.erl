%%% @doc Projection: architecture_started_v1 -> projects table (UPDATE phase_started_at)
-module(architecture_started_v1_to_projects).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{project_id := PId} = E) ->
    PhaseStartedAt = maps:get(started_at, E, erlang:system_time(millisecond)),
    Sql = "UPDATE projects SET phase_started_at = ?1 "
          "WHERE project_id = ?2",
    query_alc_store:execute(Sql, [PhaseStartedAt, PId]).
