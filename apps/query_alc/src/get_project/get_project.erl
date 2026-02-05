%%% @doc Query: get a project by ID
-module(get_project).

-export([execute/1]).

-spec execute(binary()) -> {ok, map()} | {error, not_found | term()}.
execute(ProjectId) ->
    Sql = "SELECT project_id, name, description, current_phase, status, "
          "finding_count, term_count, dossier_count, spoke_count, "
          "plan_approved, skeleton_created, implemented_spoke_count, "
          "build_verified, deployment_count, active_incidents, "
          "initiated_at, phase_started_at, completed_at "
          "FROM projects WHERE project_id = ?1",
    case query_alc_store:query(Sql, [ProjectId]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

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
