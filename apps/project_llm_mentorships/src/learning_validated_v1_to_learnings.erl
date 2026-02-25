%%% @doc Projection: learning_validated_v1 -> learnings table (UPDATE status)
-module(learning_validated_v1_to_learnings).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{learning_id := LId, validator_id := VId} = E) ->
    ValidatedAt = maps:get(validated_at, E, erlang:system_time(millisecond)),
    Sql = "UPDATE learnings SET status = status | 2, "
          "validator_id = ?1, validated_at = ?2 "
          "WHERE id = ?3",
    project_llm_mentorships_store:execute(Sql, [VId, ValidatedAt, LId]).
