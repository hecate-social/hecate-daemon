%%% @doc Projection: capability_granted_v1 → capabilities table
-module(capability_granted_v1_to_capabilities).

-export([project/1]).

%% @doc Project capability_granted_v1 event to capabilities table.
-spec project(map()) -> ok | {error, term()}.
project(#{
    event_type := <<"capability_granted_v1">>,
    capability_id := CapId,
    issuer := Issuer,
    audience := Audience,
    resource := Resource,
    actions := Actions,
    expires_at := ExpiresAt,
    granted_at := GrantedAt
}) ->
    ActionsJson = iolist_to_binary(json:encode(Actions)),

    Sql = io_lib:format(
        "INSERT OR REPLACE INTO capabilities "
        "(capability_id, issuer, audience, resource, actions, expires_at, granted_at, revoked) "
        "VALUES ('~s', '~s', '~s', '~s', '~s', ~B, ~B, 0)",
        [escape_sql(CapId), escape_sql(Issuer), escape_sql(Audience),
         escape_sql(Resource), escape_sql(ActionsJson), ExpiresAt, GrantedAt]
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
