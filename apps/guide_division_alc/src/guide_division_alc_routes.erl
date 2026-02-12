-module(guide_division_alc_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        %% Division lifecycle
        {"/api/divisions/initiate", initiate_division_api, []},
        {"/api/divisions/:division_id/phase/start", start_phase_api, []},
        {"/api/divisions/:division_id/phase/pause", pause_phase_api, []},
        {"/api/divisions/:division_id/phase/resume", resume_phase_api, []},
        {"/api/divisions/:division_id/phase/complete", complete_phase_api, []},
        {"/api/divisions/:division_id/archive", archive_division_api, []},
        %% DnA domain
        {"/api/divisions/:division_id/design/aggregates", design_aggregate_api, []},
        {"/api/divisions/:division_id/design/events", design_event_api, []},
        %% AnP domain
        {"/api/divisions/:division_id/plan/desks", plan_desk_api, []},
        {"/api/divisions/:division_id/plan/dependencies", plan_dependency_api, []},
        %% TnI domain
        {"/api/divisions/:division_id/generate/modules", generate_module_api, []},
        {"/api/divisions/:division_id/generate/tests", generate_test_api, []},
        {"/api/divisions/:division_id/test/suites", run_test_suite_api, []},
        {"/api/divisions/:division_id/test/results", record_test_result_api, []},
        %% DnO domain
        {"/api/divisions/:division_id/deploy/releases", deploy_release_api, []},
        {"/api/divisions/:division_id/deploy/rollouts", stage_rollout_api, []},
        {"/api/divisions/:division_id/monitor/health-checks", register_health_check_api, []},
        {"/api/divisions/:division_id/monitor/health-status", record_health_status_api, []},
        {"/api/divisions/:division_id/rescue/incidents", raise_incident_api, []},
        {"/api/divisions/:division_id/rescue/diagnoses", diagnose_incident_api, []},
        {"/api/divisions/:division_id/rescue/fixes", apply_fix_api, []}
    ].
