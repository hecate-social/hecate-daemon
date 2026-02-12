%%% @doc Query: list active subscriptions for an agent
-module(get_subscriptions_page).

-export([execute/1]).

-spec execute(binary()) -> {ok, [map()]} | {error, term()}.
execute(SubscriberId) ->
    Sql = "SELECT subscriber_id, mentor_id, status, subscribed_at "
          "FROM mentor_subscriptions "
          "WHERE subscriber_id = ?1 AND status & 1 != 0",
    case query_mentorships_store:query(Sql, [SubscriberId]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

row_to_map([SubscriberId, MentorId, Status, SubscribedAt]) ->
    #{
        subscriber_id => SubscriberId,
        mentor_id => MentorId,
        status => Status,
        subscribed_at => SubscribedAt
    }.
