%%% @doc Query: list findings for a project with optional filters
-module(list_findings).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(#{project_id := _ProjectId} = Filters) ->
    {WhereClauses, Params} = build_where(Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    Where = " WHERE " ++ string:join(WhereClauses, " AND "),

    ParamCount = length(Params),
    Sql = "SELECT finding_id, project_id, category, title, content, "
          "priority, recorded_at "
          "FROM findings" ++ Where ++
          " ORDER BY recorded_at DESC"
          " LIMIT ?" ++ integer_to_list(ParamCount + 1) ++
          " OFFSET ?" ++ integer_to_list(ParamCount + 2),

    AllParams = Params ++ [Limit, Offset],
    case query_alc_store:query(Sql, AllParams) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

build_where(Filters) ->
    build_where(Filters, [], [], 1).

build_where(Filters, _Clauses, _Params, N) ->
    %% project_id is always required
    ProjectId = maps:get(project_id, Filters),
    C0 = ["project_id = ?" ++ integer_to_list(N)],
    P0 = [ProjectId],
    N0 = N + 1,
    {C1, P1, N1} = maybe_add(category, Filters, C0, P0, N0),
    {C2, P2, _N2} = maybe_add(priority, Filters, C1, P1, N1),
    {C2, P2}.

maybe_add(Key, Filters, Clauses, Params, N) ->
    case maps:get(Key, Filters, undefined) of
        undefined -> {Clauses, Params, N};
        Value ->
            Clause = atom_to_list(Key) ++ " = ?" ++ integer_to_list(N),
            {Clauses ++ [Clause], Params ++ [Value], N + 1}
    end.

row_to_map({FindingId, ProjectId, Category, Title, Content,
            Priority, RecordedAt}) ->
    #{
        finding_id => FindingId,
        project_id => ProjectId,
        category => Category,
        title => Title,
        content => Content,
        priority => Priority,
        recorded_at => RecordedAt
    }.
