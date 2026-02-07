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
    ++ alc_routes().

%% Health check
health_routes() ->
    [{"/health", hecate_api_health, []}].

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

%% Application Lifecycle (ALC)
alc_routes() ->
    [
        {"/alc/projects", hecate_api_alc, [list_projects]},
        {"/alc/projects/initiate", hecate_api_alc, [initiate]},
        {"/alc/projects/:project_id", hecate_api_alc, [get_project]},
        {"/alc/projects/:project_id/discovery/start", hecate_api_alc, [discovery_start]},
        {"/alc/projects/:project_id/discovery/findings", hecate_api_alc, [discovery_list_findings]},
        {"/alc/projects/:project_id/discovery/findings/record", hecate_api_alc, [discovery_finding]},
        {"/alc/projects/:project_id/discovery/terms", hecate_api_alc, [discovery_list_terms]},
        {"/alc/projects/:project_id/discovery/terms/define", hecate_api_alc, [discovery_term]},
        {"/alc/projects/:project_id/discovery/complete", hecate_api_alc, [discovery_complete]},
        %% Phase transition
        {"/alc/projects/:project_id/transition", hecate_api_alc, [transition_phase]},
        %% Architecture & Planning
        {"/alc/projects/:project_id/architecture/start", hecate_api_alc, [architecture_start]},
        {"/alc/projects/:project_id/architecture/dossiers", hecate_api_alc, [architecture_list_dossiers]},
        {"/alc/projects/:project_id/architecture/dossiers/define", hecate_api_alc, [architecture_dossier]},
        {"/alc/projects/:project_id/architecture/spokes", hecate_api_alc, [architecture_list_spokes]},
        {"/alc/projects/:project_id/architecture/spokes/inventory", hecate_api_alc, [architecture_spoke]},
        {"/alc/projects/:project_id/architecture/plan", hecate_api_alc, [architecture_plan]},
        {"/alc/projects/:project_id/architecture/plan/approve", hecate_api_alc, [architecture_approve_plan]},
        {"/alc/projects/:project_id/architecture/complete", hecate_api_alc, [architecture_complete]},
        %% Testing & Implementation
        {"/alc/projects/:project_id/testing/start", hecate_api_alc, [testing_start]},
        {"/alc/projects/:project_id/testing/skeleton", hecate_api_alc, [testing_skeleton]},
        {"/alc/projects/:project_id/testing/implement", hecate_api_alc, [testing_implement_spoke]},
        {"/alc/projects/:project_id/testing/implementations", hecate_api_alc, [testing_list_implementations]},
        {"/alc/projects/:project_id/testing/verify", hecate_api_alc, [testing_verify_build]},
        {"/alc/projects/:project_id/testing/builds", hecate_api_alc, [testing_list_builds]},
        {"/alc/projects/:project_id/testing/complete", hecate_api_alc, [testing_complete]},
        %% Deployment & Operations
        {"/alc/projects/:project_id/deployment/start", hecate_api_alc, [deployment_start]},
        {"/alc/projects/:project_id/deployment/record", hecate_api_alc, [deployment_record]},
        {"/alc/projects/:project_id/deployment/deployments", hecate_api_alc, [deployment_list_deployments]},
        {"/alc/projects/:project_id/deployment/incident", hecate_api_alc, [deployment_report_incident]},
        {"/alc/projects/:project_id/deployment/incident/resolve", hecate_api_alc, [deployment_resolve_incident]},
        {"/alc/projects/:project_id/deployment/incidents", hecate_api_alc, [deployment_list_incidents]},
        {"/alc/projects/:project_id/deployment/complete", hecate_api_alc, [deployment_complete]}
    ].
