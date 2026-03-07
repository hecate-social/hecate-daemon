%%% @doc Query: list learnings with optional filters
-module(get_learnings_page).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]}.
execute(Filters) ->
    project_llm_mentorships_store:list_learnings(Filters).
