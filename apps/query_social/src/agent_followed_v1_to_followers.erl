%%% @doc Projection: agent_followed_v1 → followers table
%%% Updates the followers read model when agents follow each other.
-module(agent_followed_v1_to_followers).

-export([project/1]).

%% @doc Project agent_followed_v1 event to followers table.
%% Accepts event data as map (from subscription or test)
-spec project(map()) -> ok | {error, term()}.
project(#{
    follower_identity := Follower,
    followed_identity := Followed,
    followed_at := FollowedAt
}) ->
    Sql = io_lib:format(
        "INSERT OR REPLACE INTO followers "
        "(follower_identity, followed_identity, followed_at) "
        "VALUES ('~s', '~s', ~B)",
        [escape_sql(Follower), escape_sql(Followed), FollowedAt]
    ),

    case query_social_store:execute(iolist_to_binary(Sql)) of
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end;

project(_OtherEvent) ->
    {error, invalid_event_format}.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    %% Simple SQL escaping - replace single quotes
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
