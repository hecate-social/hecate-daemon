%%% @doc Query: find a learning by ID
-module(get_learning_by_id).

-export([execute/1]).

-spec execute(binary()) -> {ok, map()} | {error, not_found}.
execute(LearningId) ->
    project_llm_mentorships_store:get_learning(LearningId).
