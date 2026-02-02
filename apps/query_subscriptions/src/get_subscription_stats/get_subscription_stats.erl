%%% @doc Query: Get subscription statistics
%%% Returns aggregated stats about subscriptions.
-module(get_subscription_stats).

-export([for_agent/1, for_topic/1, global/0]).

%% Suppress supertype warnings (returns specific maps, spec uses map())
-dialyzer({nowarn_function, [for_agent/1, for_topic/1, global/0]}).

%% @doc Get subscription stats for a specific agent.
-spec for_agent(binary()) -> {ok, map()} | {error, term()}.
for_agent(AgentIdentity) ->
    Sql = io_lib:format(
        "SELECT "
        "  COUNT(*) as total, "
        "  SUM(CASE WHEN active = 1 THEN 1 ELSE 0 END) as active, "
        "  SUM(CASE WHEN active = 0 THEN 1 ELSE 0 END) as inactive "
        "FROM subscriptions "
        "WHERE agent_identity = '~s'",
        [escape_sql(AgentIdentity)]
    ),

    case query_subscriptions_store:query(iolist_to_binary(Sql)) of
        {ok, [[Total, Active, Inactive]]} ->
            {ok, #{
                agent_identity => AgentIdentity,
                total_subscriptions => Total,
                active_subscriptions => Active,
                inactive_subscriptions => Inactive
            }};
        {ok, []} ->
            {ok, #{
                agent_identity => AgentIdentity,
                total_subscriptions => 0,
                active_subscriptions => 0,
                inactive_subscriptions => 0
            }};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Get subscription stats for a specific topic.
-spec for_topic(binary()) -> {ok, map()} | {error, term()}.
for_topic(Topic) ->
    Sql = io_lib:format(
        "SELECT "
        "  COUNT(DISTINCT agent_identity) as subscriber_count, "
        "  SUM(CASE WHEN active = 1 THEN 1 ELSE 0 END) as active_count "
        "FROM subscriptions "
        "WHERE topic = '~s'",
        [escape_sql(Topic)]
    ),

    case query_subscriptions_store:query(iolist_to_binary(Sql)) of
        {ok, [[SubscriberCount, ActiveCount]]} ->
            {ok, #{
                topic => Topic,
                total_subscribers => SubscriberCount,
                active_subscribers => ActiveCount
            }};
        {ok, []} ->
            {ok, #{
                topic => Topic,
                total_subscribers => 0,
                active_subscribers => 0
            }};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Get global subscription statistics.
-spec global() -> {ok, map()} | {error, term()}.
global() ->
    Sql = <<"SELECT "
            "  COUNT(*) as total_subscriptions, "
            "  COUNT(DISTINCT agent_identity) as unique_agents, "
            "  COUNT(DISTINCT topic) as unique_topics, "
            "  SUM(CASE WHEN active = 1 THEN 1 ELSE 0 END) as active_subscriptions "
            "FROM subscriptions">>,

    case query_subscriptions_store:query(Sql) of
        {ok, [[Total, Agents, Topics, Active]]} ->
            {ok, #{
                total_subscriptions => Total,
                unique_agents => Agents,
                unique_topics => Topics,
                active_subscriptions => Active
            }};
        {ok, []} ->
            {ok, #{
                total_subscriptions => 0,
                unique_agents => 0,
                unique_topics => 0,
                active_subscriptions => 0
            }};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
