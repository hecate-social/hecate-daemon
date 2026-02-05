%%% @doc Projection: plan_approved_v1 -> projects table (UPDATE plan_approved)
-module(plan_approved_v1_to_projects).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{project_id := PId}) ->
    Sql = "UPDATE projects SET plan_approved = 1 "
          "WHERE project_id = ?1",
    query_alc_store:execute(Sql, [PId]).
