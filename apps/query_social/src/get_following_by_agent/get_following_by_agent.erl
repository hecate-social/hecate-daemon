%%% @doc Query: Get list of agents that an agent is following
-module(get_following_by_agent).

-export([execute/1]).

%% @doc Get all agents that a given agent is following.
-spec execute(binary()) -> {ok, [map()]} | {error, term()}.
execute(AgentIdentity) ->
    Sql = io_lib:format(
        "SELECT followed_identity, followed_at "
        "FROM followers "
        "WHERE follower_identity = '~s' "
        "ORDER BY followed_at DESC",
        [escape_sql(AgentIdentity)]
    ),

    case query_social_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            Following = [#{
                followed_identity => FollowedIdentity,
                followed_at => FollowedAt
            } || [FollowedIdentity, FollowedAt] <- Rows],
            {ok, Following};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
