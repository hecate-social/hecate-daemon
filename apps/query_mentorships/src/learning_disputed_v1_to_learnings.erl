%%% @doc Projection: learning_disputed_v1 -> learnings table (UPDATE dispute_count)
-module(learning_disputed_v1_to_learnings).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{learning_id := LId} = _E) ->
    Sql = "UPDATE learnings SET status = status | 16, "
          "dispute_count = dispute_count + 1 "
          "WHERE id = ?1",
    query_mentorships_store:execute(Sql, [LId]).
