%%% @doc Projection: dispute_resolved_v1 -> learnings table (UPDATE status)
-module(dispute_resolved_v1_to_learnings).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{learning_id := LId} = _E) ->
    Sql = "UPDATE learnings SET status = status | 32 WHERE id = ?1",
    query_mentors_store:execute(Sql, [LId]).
