%%% @doc Projection: capability_endorsed_v1 -> endorsements table
%%% Adds an endorsement when an agent endorses a capability.
-module(capability_endorsed_v1_to_endorsements).

-export([project/1]).

%% @doc Project capability_endorsed_v1 event to endorsements table.
-spec project(map()) -> ok | {error, term()}.
project(#{
    endorser_identity := Endorser,
    capability_mri := MRI,
    endorsed_at := EndorsedAt
} = Event) ->
    Comment = maps:get(comment, Event, null),
    CommentSql = case Comment of
        undefined -> "NULL";
        null -> "NULL";
        C when is_binary(C) -> io_lib:format("'~s'", [escape_sql(C)])
    end,

    Sql = io_lib:format(
        "INSERT OR REPLACE INTO endorsements "
        "(endorser_identity, capability_mri, comment, endorsed_at, revoked_at) "
        "VALUES ('~s', '~s', ~s, ~B, NULL)",
        [escape_sql(Endorser), escape_sql(MRI), CommentSql, EndorsedAt]
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
