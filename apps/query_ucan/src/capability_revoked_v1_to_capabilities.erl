%%% @doc Projection: capability_revoked_v1 → capabilities table
-module(capability_revoked_v1_to_capabilities).

-export([project/1]).

%% @doc Project capability_revoked_v1 event to capabilities table (mark as revoked).
-spec project(map()) -> ok | {error, term()}.
project(#{
    event_type := <<"capability_revoked_v1">>,
    capability_id := CapId,
    revoked_at := RevokedAt
}) ->
    Sql = io_lib:format(
        "UPDATE capabilities "
        "SET revoked = 1, revoked_at = ~B "
        "WHERE capability_id = '~s'",
        [RevokedAt, escape_sql(CapId)]
    ),

    case query_ucan_store:execute(iolist_to_binary(Sql)) of
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end;

project(_OtherEvent) ->
    ok.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
