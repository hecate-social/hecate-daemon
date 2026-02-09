%%% @doc Query: get a cartwheel by ID
-module(get_cartwheel).

-export([execute/1]).

-spec execute(binary()) -> {ok, map()} | {error, not_found | term()}.
execute(CartwheelId) ->
    Sql = "SELECT cartwheel_id, torch_id, context_name, description, current_phase, status, "
          "finding_count, term_count, dossier_count, spoke_count, "
          "plan_approved, skeleton_created, implemented_spoke_count, "
          "build_verified, deployment_count, active_incidents, "
          "initiated_at, phase_started_at, completed_at "
          "FROM cartwheels WHERE cartwheel_id = ?1",
    case query_cartwheels_store:query(Sql, [CartwheelId]) of
        {ok, [Row]} ->
            {ok, enrich_status(row_to_map(Row))};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

enrich_status(#{status := Status} = Row) ->
    Label = evoq_bit_flags:to_string(Status, cartwheel_aggregate:flag_map()),
    Row#{status_label => Label}.

row_to_map({CartwheelId, TorchId, ContextName, Description, CurrentPhase, Status,
            FindingCount, TermCount, DossierCount, SpokeCount,
            PlanApproved, SkeletonCreated, ImplementedSpokeCount,
            BuildVerified, DeploymentCount, ActiveIncidents,
            InitiatedAt, PhaseStartedAt, CompletedAt}) ->
    #{
        cartwheel_id => CartwheelId,
        torch_id => TorchId,
        context_name => ContextName,
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
