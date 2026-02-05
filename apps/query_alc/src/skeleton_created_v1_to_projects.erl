%%% @doc Projection: skeleton_created_v1 -> projects table (UPDATE skeleton_created)
-module(skeleton_created_v1_to_projects).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{project_id := PId}) ->
    Sql = "UPDATE projects SET skeleton_created = 1 "
          "WHERE project_id = ?1",
    query_alc_store:execute(Sql, [PId]).
