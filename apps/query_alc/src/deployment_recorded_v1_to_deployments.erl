%%% @doc Projection: deployment_recorded_v1 -> deployments table + projects counter
-module(deployment_recorded_v1_to_deployments).

-export([project/1]).

%% @doc Project deployment_recorded_v1 event to deployments table and increment project counter
-spec project(map()) -> ok | {error, term()}.
project(#{deployment_id := DepId, project_id := PId, environment := Env, version := Ver} = E) ->
    InsertSql = "INSERT OR REPLACE INTO deployments "
                "(deployment_id, project_id, environment, version, notes, deployed_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    ok = query_alc_store:execute(InsertSql, [
        DepId,
        PId,
        Env,
        Ver,
        maps:get(notes, E, undefined),
        maps:get(deployed_at, E, erlang:system_time(millisecond))
    ]),
    CountSql = "UPDATE projects SET deployment_count = deployment_count + 1 "
               "WHERE project_id = ?1",
    query_alc_store:execute(CountSql, [PId]).
