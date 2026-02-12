%%% @doc Projection: learning_endorsed_v1 -> learnings table (UPDATE endorsement_count)
-module(learning_endorsed_v1_to_learnings).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{learning_id := LId} = _E) ->
    Sql = "UPDATE learnings SET status = status | 8, "
          "endorsement_count = endorsement_count + 1 "
          "WHERE id = ?1",
    query_mentorships_store:execute(Sql, [LId]).
