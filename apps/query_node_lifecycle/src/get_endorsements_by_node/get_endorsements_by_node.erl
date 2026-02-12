%%% @doc Query: get endorsements with optional filters.
-module(get_endorsements_by_node).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    Limit = maps:get(limit, Filters, 100),
    Offset = maps:get(offset, Filters, 0),
    CapMri = maps:get(capability_mri, Filters, undefined),
    Endorser = maps:get(endorser, Filters, undefined),
    {WhereClauses, Params} = build_where(CapMri, Endorser),
    ParamIdx = length(Params),
    Sql = iolist_to_binary([
        "SELECT endorser_identity, capability_mri, comment, "
        "endorsed_at, revoked_at "
        "FROM endorsements "
        "WHERE revoked_at IS NULL",
        WhereClauses,
        " ORDER BY endorsed_at DESC"
        " LIMIT ?", integer_to_binary(ParamIdx + 1),
        " OFFSET ?", integer_to_binary(ParamIdx + 2)
    ]),
    case query_node_lifecycle_store:query(Sql, Params ++ [Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

build_where(CapMri, Endorser) ->
    {Clauses0, Params0} = case CapMri of
        undefined -> {[], []};
        _ -> {[" AND capability_mri = ?1"], [CapMri]}
    end,
    case Endorser of
        undefined ->
            {Clauses0, Params0};
        _ ->
            Idx = length(Params0) + 1,
            Clause = [" AND endorser_identity = ?", integer_to_binary(Idx)],
            {Clauses0 ++ [Clause], Params0 ++ [Endorser]}
    end.

row_to_map({EndorserIdentity, CapabilityMri, Comment, EndorsedAt, RevokedAt}) ->
    #{
        endorser_identity => EndorserIdentity,
        capability_mri => CapabilityMri,
        comment => Comment,
        endorsed_at => EndorsedAt,
        revoked_at => RevokedAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).
