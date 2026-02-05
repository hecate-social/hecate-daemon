%%% @doc Projection: architecture_completed_v1 -> projects table (UPDATE status)
-module(architecture_completed_v1_to_projects).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{project_id := PId}) ->
    Sql = "UPDATE projects SET status = status | 16 "
          "WHERE project_id = ?1",
    query_alc_store:execute(Sql, [PId]).
