%%% @doc Projection: project_initiated_v1 -> projects table
-module(project_initiated_v1_to_projects).

-export([project/1]).

%% @doc Project project_initiated_v1 event to projects table
-spec project(map()) -> ok | {error, term()}.
project(#{project_id := PId, name := Name} = E) ->
    Sql = "INSERT OR REPLACE INTO projects "
          "(project_id, name, description, current_phase, status, initiated_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    query_alc_store:execute(Sql, [
        PId,
        Name,
        maps:get(description, E, undefined),
        <<"discovery_n_analysis">>,
        3,  %% INITIATED | DISCOVERY_ACTIVE
        maps:get(initiated_at, E, erlang:system_time(millisecond))
    ]).
