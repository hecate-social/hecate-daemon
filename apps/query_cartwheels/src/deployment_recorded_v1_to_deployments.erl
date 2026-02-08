%%% @doc Projection: deployment_recorded_v1 -> deployments table + cartwheels counter
-module(deployment_recorded_v1_to_deployments).

-export([project/1]).

%% @doc Project deployment_recorded_v1 event to deployments table and increment project counter
-spec project(map()) -> ok | {error, term()}.
project(#{deployment_id := DepId, cartwheel_id := PId, environment := Env, version := Ver} = E) ->
    InsertSql = "INSERT OR REPLACE INTO deployments "
                "(deployment_id, cartwheel_id, environment, version, notes, deployed_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    ok = query_cartwheels_store:execute(InsertSql, [
        DepId,
        PId,
        Env,
        Ver,
        maps:get(notes, E, undefined),
        maps:get(deployed_at, E, erlang:system_time(millisecond))
    ]),
    CountSql = "UPDATE cartwheels SET deployment_count = deployment_count + 1 "
               "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(CountSql, [PId]).
