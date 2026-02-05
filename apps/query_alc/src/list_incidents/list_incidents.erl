%%% @doc Query: list incidents for a project with optional severity filter
-module(list_incidents).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(#{project_id := _ProjectId} = Filters) ->
    {WhereClauses, Params} = build_where(Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    Where = " WHERE " ++ string:join(WhereClauses, " AND "),

    ParamCount = length(Params),
    Sql = "SELECT incident_id, project_id, severity, description, "
          "resolution, reported_at, resolved_at "
          "FROM incidents" ++ Where ++
          " ORDER BY reported_at DESC"
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
    ProjectId = maps:get(project_id, Filters),
    C0 = ["project_id = ?" ++ integer_to_list(N)],
    P0 = [ProjectId],
    N0 = N + 1,
    {C1, P1, _N1} = maybe_add(severity, Filters, C0, P0, N0),
    {C1, P1}.

maybe_add(Key, Filters, Clauses, Params, N) ->
    case maps:get(Key, Filters, undefined) of
        undefined -> {Clauses, Params, N};
        Value ->
            Clause = atom_to_list(Key) ++ " = ?" ++ integer_to_list(N),
            {Clauses ++ [Clause], Params ++ [Value], N + 1}
    end.

row_to_map({IncidentId, ProjectId, Severity, Description,
            Resolution, ReportedAt, ResolvedAt}) ->
    #{
        incident_id => IncidentId,
        project_id => ProjectId,
        severity => Severity,
        description => Description,
        resolution => Resolution,
        reported_at => ReportedAt,
        resolved_at => ResolvedAt
    }.
