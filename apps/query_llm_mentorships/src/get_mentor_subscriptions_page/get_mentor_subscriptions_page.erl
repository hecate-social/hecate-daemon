%%% @doc Query: list active subscriptions for an agent
-module(get_mentor_subscriptions_page).

-export([execute/1]).

-spec execute(binary()) -> {ok, [map()]}.
execute(SubscriberId) ->
    project_llm_mentorships_store:get_subscriptions_for(SubscriberId).
