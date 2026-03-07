%%% @doc Query: list active mentor profiles
-module(get_mentors_page).

-export([execute/0, execute/1]).

-spec execute() -> {ok, [map()]}.
execute() ->
    execute(#{}).

-spec execute(map()) -> {ok, [map()]}.
execute(Filters) ->
    project_llm_mentorships_store:list_mentor_profiles(Filters).
