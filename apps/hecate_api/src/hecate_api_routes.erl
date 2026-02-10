%%% @doc Compiled Cowboy dispatch routes for hecate API.
%%% Single source of truth for all HTTP routes.
%%% Used by both TCP listener and Unix socket connectors.
-module(hecate_api_routes).

-export([compile/0]).

%% @doc Compile all routes into a Cowboy dispatch table.
-spec compile() -> cowboy_router:dispatch_rules().
compile() ->
    cowboy_router:compile([
        {'_', routes()}
    ]).

%% @doc Return the raw route list (before compilation).
-spec routes() -> [tuple()].
routes() ->
    health_routes()
    ++ geo_routes()
    ++ identity_routes()
    ++ pairing_routes()
    ++ capability_routes()
    ++ reputation_routes()
    ++ social_routes()
    ++ subscription_routes()
    ++ identity_management_routes()
    ++ ucan_routes()
    ++ llm_routes()
    ++ connector_routes()
    ++ mentor_routes()
    ++ venture_routes()
    ++ discovery_routes()
    ++ design_routes()
    ++ plan_routes()
    ++ generation_routes()
    ++ testing_routes()
    ++ deployment_routes()
    ++ monitoring_routes()
    ++ rescue_routes()
    ++ venture_status_routes()
    ++ torch_routes()
    ++ cartwheel_routes()
    ++ agent_routes()
    ++ telemetry_routes()
    ++ facts_routes().

%% Health check
health_routes() ->
    [{"/health", hecate_api_health, []}].

%% Geographic restrictions
geo_routes() ->
    [
        {"/api/geo/status", hecate_api_geo, [status]},
        {"/api/geo/reload", hecate_api_geo, [reload]},
        {"/api/geo/check/:ip", hecate_api_geo, [check_ip]}
    ].

%% Identity (gen_server, not event-sourced)
identity_routes() ->
    [
        {"/api/identity", hecate_api_identity, []},
        {"/api/identity/init", hecate_api_identity, [do_init]}
    ].

%% Pairing (gen_server, not event-sourced)
pairing_routes() ->
    [
        {"/api/pairing/start", hecate_api_pairing, [start]},
        {"/api/pairing/status", hecate_api_pairing, [status]},
        {"/api/pairing/cancel", hecate_api_pairing, [cancel]}
    ].

%% Capabilities — spoke handlers
capability_routes() ->
    [
        {"/api/capabilities", get_capabilities_page_api, []},
        {"/api/capabilities/announce", announce_capability_api, []},
        {"/api/capabilities/:mri", get_capability_by_mri_api, []},
        {"/api/capabilities/:mri/update", update_capability_api, []},
        {"/api/capabilities/:mri/retract", retract_capability_api, []}
    ].

%% Reputation — spoke handlers
reputation_routes() ->
    [
        {"/api/reputation/:agent_identity", get_reputation_api, []},
        {"/api/reputation/calls", get_rpc_calls_page_api, []},
        {"/api/reputation/disputes", get_disputes_page_api, []},
        {"/api/rpc/track", track_rpc_call_api, []},
        {"/api/rpc/call", call_rpc_api, []}
    ].

%% Social — spoke handlers
social_routes() ->
    [
        {"/api/social/follow", follow_agent_api, []},
        {"/api/social/unfollow", unfollow_agent_api, []},
        {"/api/social/endorse", endorse_capability_api, []},
        {"/api/social/endorsements/revoke", revoke_endorsement_api, []},
        {"/api/social/followers/:agent_identity", get_followers_by_agent_api, []},
        {"/api/social/following/:agent_identity", get_following_by_agent_api, []},
        {"/api/social/endorsements/:agent_identity", get_endorsements_by_agent_api, []},
        {"/api/social/graph/:agent_identity", get_social_graph_api, []}
    ].

%% Subscriptions — spoke handlers
subscription_routes() ->
    [
        {"/api/subscriptions", get_subscriptions_by_agent_api, []},
        {"/api/subscriptions/subscribe", subscribe_api, []},
        {"/api/subscriptions/unsubscribe", unsubscribe_api, []},
        {"/api/subscriptions/stats", get_subscription_stats_api, []}
    ].

%% Identity management — spoke handlers
identity_management_routes() ->
    [
        {"/api/identities", get_identities_page_api, []},
        {"/api/identities/register", register_identity_api, []},
        {"/api/identities/:agent_identity", find_identity_api, []},
        {"/api/identities/:agent_identity/update", update_identity_api, []}
    ].

%% UCAN — spoke handlers
ucan_routes() ->
    [
        {"/api/ucan/grant", grant_ucan_api, []},
        {"/api/ucan/revoke/:capability_id", revoke_ucan_api, []},
        {"/api/ucan/capabilities", find_ucan_capabilities_api, []},
        {"/api/ucan/verify/:capability_id", verify_ucan_api, []},
        {"/api/ucan/verify", verify_ucan_api, []}
    ].

%% LLM — spoke handlers (already vertical)
llm_routes() ->
    [
        {"/api/llm/models", get_available_llms_page_api, []},
        {"/api/llm/chat", chat_to_llm_api, []},
        {"/api/llm/health", check_llm_health_api, []},
        {"/api/llm/providers", get_providers_page_api, []},
        {"/api/llm/providers/add", add_provider_api, []},
        {"/api/llm/providers/reload", reload_providers_api, []},
        {"/api/llm/providers/:name/remove", remove_provider_api, []}
    ].

%% Connectors — spoke handlers
connector_routes() ->
    [
        {"/api/connectors", list_connectors_api, []},
        {"/api/connectors/register", register_connector_api, []},
        {"/api/connectors/:connector_id", get_connector_api, []},
        {"/api/connectors/:connector_id/revoke", revoke_connector_api, []}
    ].

%% Mentors — spoke handlers
mentor_routes() ->
    [
        {"/api/mentors/learnings", get_learnings_page_api, []},
        {"/api/mentors/learnings/submit", submit_learning_api, []},
        {"/api/mentors/learnings/:learning_id", get_learning_by_id_api, []},
        {"/api/mentors/learnings/:learning_id/validate", validate_learning_api, []},
        {"/api/mentors/learnings/:learning_id/reject", reject_learning_api, []},
        {"/api/mentors/learnings/:learning_id/endorse", endorse_learning_api, []},
        {"/api/mentors/learnings/:learning_id/dispute", dispute_learning_api, []},
        {"/api/mentors/learnings/:learning_id/resolve", resolve_learning_dispute_api, []},
        {"/api/mentors/expertise", declare_expertise_api, []},
        {"/api/mentors/expertise/withdraw", withdraw_expertise_api, []},
        {"/api/mentors/profiles", get_mentors_page_api, []},
        {"/api/mentors/profiles/:agent_id", get_mentor_profile_by_id_api, []},
        {"/api/mentors/subscribe", subscribe_to_mentor_api, []},
        {"/api/mentors/unsubscribe", unsubscribe_from_mentor_api, []},
        {"/api/mentors/subscriptions", get_subscriptions_page_api, []},
        {"/api/mentors/remote", get_remote_learnings_page_api, []}
    ].

%% Ventures (business endeavors) — desk handlers
venture_routes() ->
    [
        {"/api/venture", get_active_venture_api, []},
        {"/api/ventures/setup", setup_venture_api, []},
        {"/api/ventures", get_ventures_page_api, []},
        {"/api/ventures/:venture_id", get_venture_by_id_api, []},
        {"/api/ventures/:venture_id/vision/refine", refine_vision_api, []},
        {"/api/ventures/:venture_id/vision/submit", submit_vision_api, []},
        {"/api/ventures/:venture_id/archive", archive_venture_api, []}
    ].

%% Discovery (discover_divisions process) — desk handlers
discovery_routes() ->
    [
        %% Lifecycle
        {"/api/ventures/:venture_id/discovery/start", start_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/pause", pause_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/resume", resume_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/complete", complete_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/archive", archive_discovery_api, []},
        %% Division discovery
        {"/api/ventures/:venture_id/discovery/divisions/discover", discover_division_api, []},
        %% Queries
        {"/api/ventures/:venture_id/discovery", get_discovery_by_venture_id_api, []},
        {"/api/ventures/:venture_id/divisions", get_discovered_divisions_page_api, []}
    ].

%% Design (design_division process) — desk handlers
design_routes() ->
    [
        %% Lifecycle
        {"/api/ventures/:venture_id/divisions/:division_id/design/start", start_design_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/pause", pause_design_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/resume", resume_design_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/complete", complete_design_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/archive", archive_design_api, []},
        %% Domain commands
        {"/api/ventures/:venture_id/divisions/:division_id/design/aggregates/design", design_aggregate_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/events/design", design_event_api, []},
        %% Queries
        {"/api/ventures/:venture_id/divisions/:division_id/design", get_design_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/aggregates", get_designed_aggregates_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/events", get_designed_events_page_api, []}
    ].

%% Plan (plan_division process) — desk handlers
plan_routes() ->
    [
        %% Lifecycle
        {"/api/ventures/:venture_id/divisions/:division_id/plan/start", start_plan_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/pause", pause_plan_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/resume", resume_plan_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/complete", complete_plan_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/archive", archive_plan_api, []},
        %% Domain commands
        {"/api/ventures/:venture_id/divisions/:division_id/plan/desks/plan", plan_desk_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/dependencies/plan", plan_dependency_api, []},
        %% Queries
        {"/api/ventures/:venture_id/divisions/:division_id/plan", get_plan_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/desks", get_planned_desks_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/dependencies", get_planned_dependencies_page_api, []}
    ].

%% Generation (generate_division process) — desk handlers
generation_routes() ->
    [
        %% Lifecycle
        {"/api/ventures/:venture_id/divisions/:division_id/generation/start", start_generation_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/pause", pause_generation_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/resume", resume_generation_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/complete", complete_generation_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/archive", archive_generation_api, []},
        %% Domain commands
        {"/api/ventures/:venture_id/divisions/:division_id/generation/modules/generate", generate_module_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/tests/generate", generate_test_api, []},
        %% Queries
        {"/api/ventures/:venture_id/divisions/:division_id/generation", get_generation_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/modules", get_generated_modules_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/tests", get_generated_tests_page_api, []}
    ].

%% Testing (test_division process) — desk handlers
testing_routes() ->
    [
        %% Lifecycle
        {"/api/ventures/:venture_id/divisions/:division_id/testing/start", start_testing_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/pause", pause_testing_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/resume", resume_testing_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/complete", complete_testing_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/archive", archive_testing_api, []},
        %% Domain commands
        {"/api/ventures/:venture_id/divisions/:division_id/testing/suites/run", run_test_suite_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/results/record", record_test_result_api, []},
        %% Queries
        {"/api/ventures/:venture_id/divisions/:division_id/testing", get_testing_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/suites", get_test_suites_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/results", get_test_results_page_api, []}
    ].

%% Deployment (deploy_division process) — desk handlers
deployment_routes() ->
    [
        %% Lifecycle
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/start", start_deployment_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/pause", pause_deployment_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/resume", resume_deployment_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/complete", complete_deployment_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/archive", archive_deployment_api, []},
        %% Domain commands
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/releases/deploy", deploy_release_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/rollouts/stage", stage_rollout_api, []},
        %% Queries
        {"/api/ventures/:venture_id/divisions/:division_id/deployment", get_deployment_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/releases", get_releases_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/rollouts", get_rollout_stages_page_api, []}
    ].

%% Monitoring (monitor_division process) — desk handlers
monitoring_routes() ->
    [
        %% Lifecycle
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/start", start_monitoring_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/pause", pause_monitoring_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/resume", resume_monitoring_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/complete", complete_monitoring_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/archive", archive_monitoring_api, []},
        %% Domain commands
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/health-checks/register", register_health_check_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/health-status/record", record_health_status_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/incidents/raise", raise_incident_api, []},
        %% Queries
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring", get_monitoring_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/health-checks", get_health_checks_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/incidents", get_incidents_page_api, []}
    ].

%% Rescue (rescue_division process) — desk handlers
rescue_routes() ->
    [
        %% Lifecycle
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/start", start_rescue_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/pause", pause_rescue_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/resume", resume_rescue_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/complete", complete_rescue_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/archive", archive_rescue_api, []},
        %% Domain commands
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/diagnoses/diagnose", diagnose_incident_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/fixes/apply", apply_fix_api, []},
        %% Queries
        {"/api/ventures/:venture_id/divisions/:division_id/rescue", get_rescue_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/diagnoses", get_diagnoses_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/fixes", get_fixes_page_api, []}
    ].

%% Venture status (guide_venture orchestrator) — desk handlers
venture_status_routes() ->
    [
        {"/api/ventures/:venture_id/status", get_venture_status_api, []}
    ].

%% Torch (LEGACY — kept for Phase 8 cleanup) — spoke handlers
torch_routes() ->
    [
        {"/api/torch", get_active_torch_api, []},
        {"/api/torch/initiate", initiate_torch_api, []},
        {"/api/torches", get_torches_page_api, []},
        {"/api/torches/:torch_id", get_torch_by_id_api, []},
        {"/api/torches/:torch_id/vision/refine", refine_vision_api, []},
        {"/api/torches/:torch_id/vision/submit", submit_vision_api, []},
        {"/api/torches/:torch_id/archive", archive_torch_api, []},
        {"/api/torches/:torch_id/cartwheels/identify", identify_cartwheel_api, []}
    ].

%% Cartwheel (bounded contexts) — spoke handlers (already vertical)
%%
%% NOTE: There is NO direct cartwheel creation endpoint.
%% Cartwheels are created through the parent-child pattern:
%%   Torch identifies cartwheel → cartwheel_identified_v1 → manage_cartwheels listener
%%   → initiate_cartwheel command → cartwheel_initiated_v1 event
%% Use: POST /api/torches/:torch_id/cartwheels/identify
cartwheel_routes() ->
    [
        %% Core cartwheel routes (read-only + lifecycle operations)
        {"/api/cartwheel", get_active_cartwheel_api, []},
        {"/api/cartwheels", get_cartwheels_page_api, []},
        %% No initiate endpoint - cartwheels created via torch identification
        {"/api/cartwheels/:cartwheel_id", get_cartwheel_by_id_api, []},
        {"/api/cartwheels/:cartwheel_id/transition", transition_phase_api, []},
        %% Discovery & Analysis phase
        {"/api/cartwheels/:cartwheel_id/discovery/start", start_discovery_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/findings", get_findings_page_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/findings/record", record_finding_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/terms", get_terms_page_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/terms/define", define_term_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/complete", complete_discovery_api, []},
        %% Architecture & Planning phase
        {"/api/cartwheels/:cartwheel_id/architecture/start", start_architecture_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/dossiers", get_dossier_designs_page_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/dossiers/define", define_dossier_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/spokes", get_spoke_inventory_page_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/spokes/inventory", inventory_spoke_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/plan", draft_plan_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/plan/approve", approve_plan_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/complete", complete_architecture_api, []},
        %% Testing & Implementation phase
        {"/api/cartwheels/:cartwheel_id/testing/start", start_testing_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/skeleton", create_skeleton_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/implement", implement_spoke_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/implementations", get_spoke_implementations_page_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/verify", verify_build_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/builds", get_build_verifications_page_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/complete", complete_testing_api, []},
        %% Deployment & Operations phase
        {"/api/cartwheels/:cartwheel_id/deployment/start", start_deployment_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/record", record_deployment_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/deployments", get_deployments_page_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/incident", report_incident_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/incident/resolve", resolve_incident_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/incidents", get_incidents_page_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/complete", complete_deployment_api, []}
    ].

%% Agents (specialists and generalists)
agent_routes() ->
    [
        {"/api/agents", hecate_api_agents, [list]},
        {"/api/agents/:agent_id", hecate_api_agents, [get]}
    ].

%% Telemetry and cost tracking
telemetry_routes() ->
    [
        {"/api/telemetry/cost", hecate_api_telemetry, [total_cost]},
        {"/api/telemetry/cost/:torch_id", hecate_api_telemetry, [cost_by_torch]},
        {"/api/telemetry/cost/:torch_id/cartwheels", hecate_api_telemetry, [cost_by_cartwheel]},
        {"/api/telemetry/cost/:torch_id/agents", hecate_api_telemetry, [cost_by_agent]}
    ].

%% Facts stream (SSE for TUI fact delivery)
facts_routes() ->
    [{"/api/facts/stream", tui_facts_stream_api, []}].
