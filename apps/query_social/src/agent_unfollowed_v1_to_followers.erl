%%% @doc Projection: agent_unfollowed_v1 -> followers table
%%% Removes a follower relationship when an agent unfollows another.
-module(agent_unfollowed_v1_to_followers).

-export([project/1]).

%% @doc Project agent_unfollowed_v1 event by removing from followers table.
-spec project(map()) -> ok | {error, term()}.
project(#{
    follower_identity := Follower,
    followed_identity := Followed
}) ->
    Sql = io_lib:format(
        "DELETE FROM followers "
        "WHERE follower_identity = '~s' AND followed_identity = '~s'",
        [escape_sql(Follower), escape_sql(Followed)]
    ),

    case query_social_store:execute(iolist_to_binary(Sql)) of
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end;

project(_OtherEvent) ->
    {error, invalid_event_format}.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
