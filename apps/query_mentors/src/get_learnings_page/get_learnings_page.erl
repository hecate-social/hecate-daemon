%%% @doc Query: list learnings with optional filters
-module(get_learnings_page).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(Filters) ->
    {WhereClauses, Params} = build_where(Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    Where = case WhereClauses of
        [] -> "";
        _ -> " WHERE " ++ string:join(WhereClauses, " AND ")
    end,

    ParamCount = length(Params),
    Sql = "SELECT id, submitter_id, category, domain, tags, title, "
          "description, bad_example, good_example, context, severity, "
          "confidence, source, status, validator_id, endorsement_count, "
          "dispute_count, submitted_at, validated_at "
          "FROM learnings" ++ Where ++
          " ORDER BY submitted_at DESC"
          " LIMIT ?" ++ integer_to_list(ParamCount + 1) ++
          " OFFSET ?" ++ integer_to_list(ParamCount + 2),

    AllParams = Params ++ [Limit, Offset],
    case query_mentors_store:query(Sql, AllParams) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

build_where(Filters) ->
    build_where(Filters, [], [], 1).

build_where(Filters, Clauses, Params, N) ->
    {C1, P1, N1} = maybe_add(domain, Filters, Clauses, Params, N),
    {C2, P2, N2} = maybe_add(category, Filters, C1, P1, N1),
    {C3, P3, N3} = maybe_add_status(Filters, C2, P2, N2),
    {C4, P4, _N4} = maybe_add(submitter_id, Filters, C3, P3, N3),
    {C4, P4}.

maybe_add(Key, Filters, Clauses, Params, N) ->
    case maps:get(Key, Filters, undefined) of
        undefined -> {Clauses, Params, N};
        Value ->
            Clause = atom_to_list(Key) ++ " = ?" ++ integer_to_list(N),
            {Clauses ++ [Clause], Params ++ [Value], N + 1}
    end.

maybe_add_status(Filters, Clauses, Params, N) ->
    case maps:get(status_mask, Filters, undefined) of
        undefined -> {Clauses, Params, N};
        Mask ->
            Clause = "status & ?" ++ integer_to_list(N) ++ " != 0",
            {Clauses ++ [Clause], Params ++ [Mask], N + 1}
    end.

row_to_map({Id, SubmitterId, Category, Domain, TagsJson, Title,
            Desc, BadEx, GoodEx, Context, Severity, Confidence,
            Source, Status, ValidatorId, EndCount, DispCount,
            SubmittedAt, ValidatedAt}) ->
    Tags = case TagsJson of
        undefined -> [];
        null -> [];
        Bin when is_binary(Bin) -> jsx:decode(Bin, [return_maps]);
        _ -> []
    end,
    #{
        id => Id,
        submitter_id => SubmitterId,
        category => Category,
        domain => Domain,
        tags => Tags,
        title => Title,
        description => Desc,
        bad_example => BadEx,
        good_example => GoodEx,
        context => Context,
        severity => Severity,
        confidence => Confidence,
        source => Source,
        status => Status,
        validator_id => ValidatorId,
        endorsement_count => EndCount,
        dispute_count => DispCount,
        submitted_at => SubmittedAt,
        validated_at => ValidatedAt
    }.
