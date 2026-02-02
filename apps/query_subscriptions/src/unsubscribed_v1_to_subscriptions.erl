%%% @doc Projection: unsubscribed_v1 → subscriptions table
-module(unsubscribed_v1_to_subscriptions).

-export([project/1]).

%% @doc Project unsubscribed_v1 event to subscriptions table (mark as inactive).
-spec project(map()) -> ok | {error, term()}.
project(#{
    event_type := <<"unsubscribed_v1">>,
    agent_identity := Agent,
    topic := Topic
}) ->
    Sql = io_lib:format(
        "UPDATE subscriptions "
        "SET active = 0 "
        "WHERE agent_identity = '~s' AND topic = '~s'",
        [escape_sql(Agent), escape_sql(Topic)]
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
