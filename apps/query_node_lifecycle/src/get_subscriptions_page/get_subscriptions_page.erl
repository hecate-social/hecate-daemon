%%% @doc Query: list active subscriptions with pagination.
-module(get_subscriptions_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    Limit = maps:get(limit, Filters, 100),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT agent_identity, topic, filter, subscribed_at, active "
          "FROM subscriptions "
          "WHERE active = 1 "
          "ORDER BY subscribed_at DESC "
          "LIMIT ?1 OFFSET ?2",
    case query_node_lifecycle_store:query(Sql, [Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({AgentIdentity, Topic, Filter, SubscribedAt, _Active}) ->
    #{
        agent_identity => AgentIdentity,
        topic => Topic,
        filter => Filter,
        subscribed_at => SubscribedAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).
