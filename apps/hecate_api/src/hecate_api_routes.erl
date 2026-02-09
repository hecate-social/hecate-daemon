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

%% Identity
identity_routes() ->
    [
        {"/identity", hecate_api_identity, []},
        {"/identity/init", hecate_api_identity, [do_init]}
    ].

%% Pairing
pairing_routes() ->
    [
        {"/api/pairing/start", hecate_api_pairing, [start]},
        {"/api/pairing/status", hecate_api_pairing, [status]},
        {"/api/pairing/cancel", hecate_api_pairing, [cancel]}
    ].

%% Capabilities
capability_routes() ->
    [
        {"/capabilities/announce", hecate_api_capabilities, [announce]},
        {"/capabilities/discover", hecate_api_capabilities, [discover]},
        {"/capabilities/:mri", hecate_api_capabilities, [get]},
        {"/capabilities/:mri/update", hecate_api_capabilities, [update]},
        {"/capabilities/:mri/retract", hecate_api_capabilities, [retract]}
    ].

%% Reputation
reputation_routes() ->
    [
        {"/reputation/:agent_identity", hecate_api_reputation, [get]},
        {"/rpc-calls", hecate_api_reputation, [list_calls]},
        {"/disputes", hecate_api_reputation, [list_disputes]},
        {"/rpc/track", hecate_api_rpc, [track]},
        {"/api/rpc/call", hecate_api_rpc, [call]}
    ].

%% Social
social_routes() ->
    [
        {"/social/follow", hecate_api_social, [follow]},
        {"/social/unfollow", hecate_api_social, [unfollow]},
        {"/social/endorse", hecate_api_social, [endorse]},
        {"/social/endorsement/revoke", hecate_api_social, [revoke_endorsement]},
        {"/social/followers/:agent_identity", hecate_api_social, [get_followers]},
        {"/social/following/:agent_identity", hecate_api_social, [get_following]},
        {"/social/endorsements/:agent_identity", hecate_api_social, [get_endorsements]},
        {"/social/graph/:agent_identity", hecate_api_social, [get_social_graph]}
    ].

%% Subscriptions
subscription_routes() ->
    [
        {"/subscriptions", hecate_api_subscriptions, [list]},
        {"/subscriptions/subscribe", hecate_api_subscriptions, [subscribe]},
        {"/subscriptions/unsubscribe", hecate_api_subscriptions, [unsubscribe]},
        {"/subscriptions/stats", hecate_api_subscriptions, [stats]}
    ].

%% Identity management
identity_management_routes() ->
    [
        {"/agents", hecate_api_identities, [list]},
        {"/agents/register", hecate_api_identities, [register]},
        {"/agents/:agent_identity", hecate_api_identities, [get]},
        {"/agents/:agent_identity/update", hecate_api_identities, [update]}
    ].

%% UCAN
ucan_routes() ->
    [
        {"/ucan/grant", hecate_api_ucan, [grant]},
        {"/ucan/revoke/:capability_id", hecate_api_ucan, [revoke]},
        {"/ucan/capabilities", hecate_api_ucan, [list]},
        {"/ucan/verify/:capability_id", hecate_api_ucan, [verify]},
        {"/ucan/verify", hecate_api_ucan, [verify_action]}
    ].

%% LLM - vertical handlers in spokes
llm_routes() ->
    [
        {"/api/llm/models", list_available_llms_api, []},
        {"/api/llm/chat", chat_to_llm_api, []},
        {"/api/llm/health", check_llm_health_api, []},
        {"/api/llm/providers", list_providers_api, []},
        {"/api/llm/providers/add", add_provider_api, []},
        {"/api/llm/providers/reload", reload_providers_api, []},
        {"/api/llm/providers/:name/remove", remove_provider_api, []}
    ].

%% Connectors
connector_routes() ->
    [
        {"/connectors", hecate_api_connectors, [list]},
        {"/connectors/register", hecate_api_connectors, [register]},
        {"/connectors/:connector_id", hecate_api_connectors, [get]},
        {"/connectors/:connector_id/revoke", hecate_api_connectors, [revoke]}
    ].

%% Mentors
mentor_routes() ->
    [
        {"/mentors/learnings", hecate_api_mentors, [list_learnings]},
        {"/mentors/learnings/submit", hecate_api_mentors, [submit]},
        {"/mentors/learnings/:learning_id", hecate_api_mentors, [get_learning]},
        {"/mentors/learnings/:learning_id/validate", hecate_api_mentors, [validate]},
        {"/mentors/learnings/:learning_id/reject", hecate_api_mentors, [reject]},
        {"/mentors/learnings/:learning_id/endorse", hecate_api_mentors, [endorse]},
        {"/mentors/learnings/:learning_id/dispute", hecate_api_mentors, [dispute]},
        {"/mentors/learnings/:learning_id/resolve", hecate_api_mentors, [resolve]},
        {"/mentors/expertise", hecate_api_mentors, [declare]},
        {"/mentors/expertise/withdraw", hecate_api_mentors, [withdraw]},
        {"/mentors/profiles", hecate_api_mentors, [list_mentors]},
        {"/mentors/profiles/:agent_id", hecate_api_mentors, [get_profile]},
        {"/mentors/subscribe", hecate_api_mentors, [subscribe]},
        {"/mentors/unsubscribe", hecate_api_mentors, [unsubscribe]},
        {"/mentors/subscriptions", hecate_api_mentors, [list_subs]},
        {"/mentors/remote", hecate_api_mentors, [list_remote]}
    ].

%% Torch (business endeavors) - vertical handlers in spokes
torch_routes() ->
    [
        {"/api/torch", get_active_torch_api, []},
        {"/api/torch/initiate", initiate_torch_api, []},
        {"/api/torches", list_torches_api, []},
        {"/api/torches/:torch_id", get_torch_api, []},
        {"/api/torches/:torch_id/vision/refine", refine_vision_api, []},
        {"/api/torches/:torch_id/vision/submit", submit_vision_api, []},
        {"/api/torches/:torch_id/archive", archive_torch_api, []},
        {"/api/torches/:torch_id/cartwheels/identify", identify_cartwheel_api, []}
    ].

%% Cartwheel (bounded contexts) - vertical handlers in spokes
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
        {"/api/cartwheels", list_cartwheels_api, []},
        %% No initiate endpoint - cartwheels created via torch identification
        {"/api/cartwheels/:cartwheel_id", get_cartwheel_api, []},
        {"/api/cartwheels/:cartwheel_id/transition", transition_phase_api, []},
        %% Discovery & Analysis phase
        {"/api/cartwheels/:cartwheel_id/discovery/start", start_discovery_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/findings", list_findings_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/findings/record", record_finding_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/terms", list_terms_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/terms/define", define_term_api, []},
        {"/api/cartwheels/:cartwheel_id/discovery/complete", complete_discovery_api, []},
        %% Architecture & Planning phase
        {"/api/cartwheels/:cartwheel_id/architecture/start", start_architecture_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/dossiers", list_dossier_designs_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/dossiers/define", define_dossier_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/spokes", list_spoke_inventory_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/spokes/inventory", inventory_spoke_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/plan", draft_plan_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/plan/approve", approve_plan_api, []},
        {"/api/cartwheels/:cartwheel_id/architecture/complete", complete_architecture_api, []},
        %% Testing & Implementation phase
        {"/api/cartwheels/:cartwheel_id/testing/start", start_testing_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/skeleton", create_skeleton_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/implement", implement_spoke_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/implementations", list_spoke_implementations_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/verify", verify_build_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/builds", list_build_verifications_api, []},
        {"/api/cartwheels/:cartwheel_id/testing/complete", complete_testing_api, []},
        %% Deployment & Operations phase
        {"/api/cartwheels/:cartwheel_id/deployment/start", start_deployment_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/record", record_deployment_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/deployments", list_deployments_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/incident", report_incident_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/incident/resolve", resolve_incident_api, []},
        {"/api/cartwheels/:cartwheel_id/deployment/incidents", list_incidents_api, []},
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
