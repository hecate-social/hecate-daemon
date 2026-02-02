%%% @doc Projection: subscribed_v1 → subscriptions table
-module(subscribed_v1_to_subscriptions).

-export([project/1]).

%% @doc Project subscribed_v1 event to subscriptions table.
-spec project(map()) -> ok | {error, term()}.
project(#{
    event_type := <<"subscribed_v1">>,
    agent_identity := Agent,
    topic := Topic,
    filter := Filter,
    subscribed_at := SubscribedAt
}) ->
    FilterJson = case Filter of
        undefined -> <<"null">>;
        _ -> json:encode(Filter)
    end,

    Sql = io_lib:format(
        "INSERT OR REPLACE INTO subscriptions "
        "(agent_identity, topic, filter, subscribed_at, active) "
        "VALUES ('~s', '~s', '~s', ~B, 1)",
        [escape_sql(Agent), escape_sql(Topic), escape_sql(FilterJson), SubscribedAt]
    ),

    case query_subscriptions_store:execute(iolist_to_binary(Sql)) of
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end;

project(_OtherEvent) ->
    ok.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
