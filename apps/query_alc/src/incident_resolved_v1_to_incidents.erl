%%% @doc Projection: incident_resolved_v1 -> incidents table (UPDATE resolution) + decrement counter
-module(incident_resolved_v1_to_incidents).

-export([project/1]).

%% @doc Project incident_resolved_v1 event: set resolution and decrement active_incidents counter
-spec project(map()) -> ok | {error, term()}.
project(#{incident_id := IncId, project_id := PId} = E) ->
    Resolution = maps:get(resolution, E, undefined),
    ResolvedAt = maps:get(resolved_at, E, erlang:system_time(millisecond)),
    UpdateSql = "UPDATE incidents SET resolution = ?1, resolved_at = ?2 "
                "WHERE incident_id = ?3",
    ok = query_alc_store:execute(UpdateSql, [Resolution, ResolvedAt, IncId]),
    CountSql = "UPDATE projects SET active_incidents = MAX(0, active_incidents - 1) "
               "WHERE project_id = ?1",
    query_alc_store:execute(CountSql, [PId]).
