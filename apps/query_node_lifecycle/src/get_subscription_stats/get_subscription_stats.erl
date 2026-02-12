%%% @doc Query: get subscription statistics.
-module(get_subscription_stats).
-export([get/0]).

-spec get() -> {ok, map()} | {error, term()}.
get() ->
    TotalSql = "SELECT COUNT(*) FROM subscriptions WHERE active = 1",
    TopicsSql = "SELECT topic, COUNT(*) as cnt "
                "FROM subscriptions WHERE active = 1 "
                "GROUP BY topic ORDER BY cnt DESC LIMIT 10",
    case query_node_lifecycle_store:query(TotalSql, []) of
        {ok, [[TotalActive]]} ->
            case query_node_lifecycle_store:query(TopicsSql, []) of
                {ok, TopicRows} ->
                    TopTopics = [topic_row_to_map(R) || R <- TopicRows],
                    {ok, #{
                        total_active => TotalActive,
                        top_topics => TopTopics
                    }};
                {error, Reason} ->
                    {error, Reason}
            end;
        {ok, []} ->
            {ok, #{total_active => 0, top_topics => []}};
        {error, Reason} ->
            {error, Reason}
    end.

topic_row_to_map([Topic, Count]) ->
    #{topic => Topic, count => Count}.
