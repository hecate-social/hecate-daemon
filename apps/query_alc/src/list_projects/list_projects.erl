%%% @doc Query: list ALC projects with optional filters
-module(list_projects).

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
    Sql = "SELECT project_id, name, description, current_phase, status, "
          "finding_count, term_count, dossier_count, spoke_count, "
          "plan_approved, skeleton_created, implemented_spoke_count, "
          "build_verified, deployment_count, active_incidents, "
          "initiated_at, phase_started_at, completed_at "
          "FROM projects" ++ Where ++
          " ORDER BY initiated_at DESC"
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

build_where(Filters, Clauses, Params, N) ->
    {C1, P1, N1} = maybe_add(current_phase, Filters, Clauses, Params, N),
    {C2, P2, _N2} = maybe_add_status(Filters, C1, P1, N1),
    {C2, P2}.

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

row_to_map({ProjectId, Name, Description, CurrentPhase, Status,
            FindingCount, TermCount, DossierCount, SpokeCount,
            PlanApproved, SkeletonCreated, ImplementedSpokeCount,
            BuildVerified, DeploymentCount, ActiveIncidents,
            InitiatedAt, PhaseStartedAt, CompletedAt}) ->
    #{
        project_id => ProjectId,
        name => Name,
        description => Description,
        current_phase => CurrentPhase,
        status => Status,
        finding_count => FindingCount,
        term_count => TermCount,
        dossier_count => DossierCount,
        spoke_count => SpokeCount,
        plan_approved => PlanApproved,
        skeleton_created => SkeletonCreated,
        implemented_spoke_count => ImplementedSpokeCount,
        build_verified => BuildVerified,
        deployment_count => DeploymentCount,
        active_incidents => ActiveIncidents,
        initiated_at => InitiatedAt,
        phase_started_at => PhaseStartedAt,
        completed_at => CompletedAt
    }.
