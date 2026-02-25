%%% @doc Projection: learning_rejected_v1 -> learnings table (UPDATE status)
-module(learning_rejected_v1_to_learnings).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{learning_id := LId, validator_id := VId} = _E) ->
    Sql = "UPDATE learnings SET status = status | 4, "
          "validator_id = ?1 "
          "WHERE id = ?2",
    project_llm_mentorships_store:execute(Sql, [VId, LId]).
