%%% @doc Query: Get active subscriptions for an agent
-module(get_subscriptions).

-export([execute/1]).

%% @doc Get all active subscriptions for a given agent.
-spec execute(binary()) -> {ok, [map()]} | {error, term()}.
execute(AgentIdentity) ->
    Sql = io_lib:format(
        "SELECT topic, filter, subscribed_at "
        "FROM subscriptions "
        "WHERE agent_identity = '~s' AND active = 1 "
        "ORDER BY subscribed_at DESC",
        [escape_sql(AgentIdentity)]
    ),

    case query_subscriptions_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            Subscriptions = [#{
                topic => Topic,
                filter => decode_filter(Filter),
                subscribed_at => SubscribedAt
            } || [Topic, Filter, SubscribedAt] <- Rows],
            {ok, Subscriptions};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).

decode_filter(<<"null">>) -> undefined;
decode_filter(FilterJson) when is_binary(FilterJson) ->
    case json:decode(FilterJson) of
        Map when is_map(Map) -> Map;
        _ -> undefined
    end;
decode_filter(_) -> undefined.
