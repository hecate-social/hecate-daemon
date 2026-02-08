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
    ++ telemetry_routes().

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

%% LLM
llm_routes() ->
    [
        {"/api/llm/models", hecate_api_llm, [models]},
        {"/api/llm/chat", hecate_api_llm, [chat]},
        {"/api/llm/health", hecate_api_llm, [health]},
        {"/api/llm/providers", hecate_api_llm, [providers]},
        {"/api/llm/providers/add", hecate_api_llm, [add_provider]},
        {"/api/llm/providers/reload", hecate_api_llm, [reload_providers]},
        {"/api/llm/providers/:name/remove", hecate_api_llm, [remove_provider]}
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

%% Torch (business endeavors)
torch_routes() ->
    [
        {"/api/torch", hecate_api_torch, [get]},
        {"/api/torch/initiate", hecate_api_torch, [initiate]},
        {"/api/torches", hecate_api_torch, [list]},
        {"/api/torches/:torch_id", hecate_api_torch, [get_by_id]},
        {"/api/torches/:torch_id/cartwheels/identify", hecate_api_torch, [identify_cartwheel]}
    ].

%% Cartwheel (bounded contexts) - replaces alc_routes
cartwheel_routes() ->
    [
        {"/api/cartwheel", hecate_api_cartwheel, [get_active]},
        {"/api/cartwheels", hecate_api_cartwheel, [list]},
        {"/api/cartwheels/:cartwheel_id", hecate_api_cartwheel, [get]},
        %% Legacy ALC routes for backward compatibility
        {"/alc/projects", hecate_api_cartwheel, [list]},
        {"/alc/projects/initiate", hecate_api_cartwheel, [initiate]},
        {"/alc/projects/:cartwheel_id", hecate_api_cartwheel, [get]},
        {"/alc/projects/:cartwheel_id/discovery/start", hecate_api_cartwheel, [discovery_start]},
        {"/alc/projects/:cartwheel_id/discovery/findings", hecate_api_cartwheel, [discovery_list_findings]},
        {"/alc/projects/:cartwheel_id/discovery/findings/record", hecate_api_cartwheel, [discovery_finding]},
        {"/alc/projects/:cartwheel_id/discovery/terms", hecate_api_cartwheel, [discovery_list_terms]},
        {"/alc/projects/:cartwheel_id/discovery/terms/define", hecate_api_cartwheel, [discovery_term]},
        {"/alc/projects/:cartwheel_id/discovery/complete", hecate_api_cartwheel, [discovery_complete]},
        {"/alc/projects/:cartwheel_id/transition", hecate_api_cartwheel, [transition_phase]},
        {"/alc/projects/:cartwheel_id/architecture/start", hecate_api_cartwheel, [architecture_start]},
        {"/alc/projects/:cartwheel_id/architecture/dossiers", hecate_api_cartwheel, [architecture_list_dossiers]},
        {"/alc/projects/:cartwheel_id/architecture/dossiers/define", hecate_api_cartwheel, [architecture_dossier]},
        {"/alc/projects/:cartwheel_id/architecture/spokes", hecate_api_cartwheel, [architecture_list_spokes]},
        {"/alc/projects/:cartwheel_id/architecture/spokes/inventory", hecate_api_cartwheel, [architecture_spoke]},
        {"/alc/projects/:cartwheel_id/architecture/plan", hecate_api_cartwheel, [architecture_plan]},
        {"/alc/projects/:cartwheel_id/architecture/plan/approve", hecate_api_cartwheel, [architecture_approve_plan]},
        {"/alc/projects/:cartwheel_id/architecture/complete", hecate_api_cartwheel, [architecture_complete]},
        {"/alc/projects/:cartwheel_id/testing/start", hecate_api_cartwheel, [testing_start]},
        {"/alc/projects/:cartwheel_id/testing/skeleton", hecate_api_cartwheel, [testing_skeleton]},
        {"/alc/projects/:cartwheel_id/testing/implement", hecate_api_cartwheel, [testing_implement_spoke]},
        {"/alc/projects/:cartwheel_id/testing/implementations", hecate_api_cartwheel, [testing_list_implementations]},
        {"/alc/projects/:cartwheel_id/testing/verify", hecate_api_cartwheel, [testing_verify_build]},
        {"/alc/projects/:cartwheel_id/testing/builds", hecate_api_cartwheel, [testing_list_builds]},
        {"/alc/projects/:cartwheel_id/testing/complete", hecate_api_cartwheel, [testing_complete]},
        {"/alc/projects/:cartwheel_id/deployment/start", hecate_api_cartwheel, [deployment_start]},
        {"/alc/projects/:cartwheel_id/deployment/record", hecate_api_cartwheel, [deployment_record]},
        {"/alc/projects/:cartwheel_id/deployment/deployments", hecate_api_cartwheel, [deployment_list_deployments]},
        {"/alc/projects/:cartwheel_id/deployment/incident", hecate_api_cartwheel, [deployment_report_incident]},
        {"/alc/projects/:cartwheel_id/deployment/incident/resolve", hecate_api_cartwheel, [deployment_resolve_incident]},
        {"/alc/projects/:cartwheel_id/deployment/incidents", hecate_api_cartwheel, [deployment_list_incidents]},
        {"/alc/projects/:cartwheel_id/deployment/complete", hecate_api_cartwheel, [deployment_complete]}
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
