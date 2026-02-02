%%% @doc Query: Find active capabilities for an agent
-module(find_capabilities).

-export([execute/1, by_issuer/1, by_audience/1]).

%% @doc Get all active (non-revoked, non-expired) capabilities for an audience.
-spec execute(binary()) -> {ok, [map()]} | {error, term()}.
execute(Audience) ->
    by_audience(Audience).

%% @doc Get all capabilities issued by a specific agent.
-spec by_issuer(binary()) -> {ok, [map()]} | {error, term()}.
by_issuer(Issuer) ->
    Now = erlang:system_time(millisecond),
    Sql = io_lib:format(
        "SELECT capability_id, issuer, audience, resource, actions, "
        "       expires_at, granted_at, revoked, revoked_at "
        "FROM capabilities "
        "WHERE issuer = '~s' AND revoked = 0 AND expires_at > ~B "
        "ORDER BY granted_at DESC",
        [escape_sql(Issuer), Now]
    ),

    query_and_decode(Sql).

%% @doc Get all capabilities granted to a specific agent.
-spec by_audience(binary()) -> {ok, [map()]} | {error, term()}.
by_audience(Audience) ->
    Now = erlang:system_time(millisecond),
    Sql = io_lib:format(
        "SELECT capability_id, issuer, audience, resource, actions, "
        "       expires_at, granted_at, revoked, revoked_at "
        "FROM capabilities "
        "WHERE audience = '~s' AND revoked = 0 AND expires_at > ~B "
        "ORDER BY granted_at DESC",
        [escape_sql(Audience), Now]
    ),

    query_and_decode(Sql).

%% Internal functions

query_and_decode(Sql) ->
    case query_ucan_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            Capabilities = [#{
                capability_id => CapId,
                issuer => Issuer,
                audience => Audience,
                resource => Resource,
                actions => json:decode(Actions),
                expires_at => ExpiresAt,
                granted_at => GrantedAt,
                revoked => Revoked =:= 1,
                revoked_at => RevokedAt
            } || [CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt, Revoked, RevokedAt] <- Rows],
            {ok, Capabilities};
        {error, Reason} ->
            {error, Reason}
    end.

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
