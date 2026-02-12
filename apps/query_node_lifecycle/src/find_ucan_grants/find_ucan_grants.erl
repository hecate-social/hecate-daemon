%%% @doc Query: find UCAN grants with optional filters.
-module(find_ucan_grants).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    Limit = maps:get(limit, Filters, 100),
    Offset = maps:get(offset, Filters, 0),
    ActiveOnly = maps:get(active_only, Filters, false),
    Issuer = maps:get(issuer, Filters, undefined),
    Audience = maps:get(audience, Filters, undefined),
    {WhereClauses, Params} = build_where(ActiveOnly, Issuer, Audience),
    ParamIdx = length(Params),
    Sql = iolist_to_binary([
        "SELECT capability_id, issuer, audience, resource, actions, "
        "expires_at, granted_at, revoked, revoked_at "
        "FROM ucan_grants",
        WhereClauses,
        " ORDER BY granted_at DESC"
        " LIMIT ?", integer_to_binary(ParamIdx + 1),
        " OFFSET ?", integer_to_binary(ParamIdx + 2)
    ]),
    case query_node_lifecycle_store:query(Sql, Params ++ [Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

build_where(ActiveOnly, Issuer, Audience) ->
    {C0, P0} = case ActiveOnly of
        true -> {[" WHERE revoked = 0"], []};
        _ -> {[], []}
    end,
    {C1, P1} = case Issuer of
        undefined -> {C0, P0};
        _ ->
            Conjunction = where_conjunction(C0),
            Idx = length(P0) + 1,
            {C0 ++ [Conjunction, "issuer = ?", integer_to_binary(Idx)],
             P0 ++ [Issuer]}
    end,
    {C2, P2} = case Audience of
        undefined -> {C1, P1};
        _ ->
            Conj2 = where_conjunction(C1),
            Idx2 = length(P1) + 1,
            {C1 ++ [Conj2, "audience = ?", integer_to_binary(Idx2)],
             P1 ++ [Audience]}
    end,
    {C2, P2}.

where_conjunction([]) -> " WHERE ";
where_conjunction(_) -> " AND ".

row_to_map({CapabilityId, Issuer, Audience, Resource, Actions,
            ExpiresAt, GrantedAt, Revoked, RevokedAt}) ->
    #{
        capability_id => CapabilityId,
        issuer => Issuer,
        audience => Audience,
        resource => Resource,
        actions => decode_json(Actions),
        expires_at => ExpiresAt,
        granted_at => GrantedAt,
        revoked => Revoked =:= 1,
        revoked_at => RevokedAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).

decode_json(null) -> null;
decode_json(undefined) -> null;
decode_json(Val) when is_binary(Val) -> json:decode(Val);
decode_json(Val) -> Val.
