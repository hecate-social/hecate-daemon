%%% @doc Query: get a mentor profile by agent_id
-module(get_mentor_profile_by_id).

-export([execute/1]).

-spec execute(binary()) -> {ok, map()} | {error, not_found}.
execute(AgentId) ->
    project_llm_mentorships_store:get_mentor_profile(AgentId).
