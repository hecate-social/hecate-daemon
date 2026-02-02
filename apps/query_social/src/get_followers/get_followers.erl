%%% @doc Query: Get list of followers for an agent
-module(get_followers).

-export([execute/1]).

%% @doc Get all followers for a given agent.
-spec execute(binary()) -> {ok, [map()]} | {error, term()}.
execute(AgentIdentity) ->
    Sql = io_lib:format(
        "SELECT follower_identity, followed_at "
        "FROM followers "
        "WHERE followed_identity = '~s' "
        "ORDER BY followed_at DESC",
        [escape_sql(AgentIdentity)]
    ),

    case query_social_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            Followers = [#{
                follower_identity => FollowerIdentity,
                followed_at => FollowedAt
            } || [FollowerIdentity, FollowedAt] <- Rows],
            {ok, Followers};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
