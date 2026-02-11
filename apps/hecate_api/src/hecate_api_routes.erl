%%% @doc Compiled Cowboy dispatch routes for hecate API.
%%% Thin assembler — each domain app owns its routes via {app}_routes:routes/0.
-module(hecate_api_routes).

-export([compile/0]).

-spec compile() -> cowboy_router:dispatch_rules().
compile() ->
    cowboy_router:compile([
        {'_', routes()}
    ]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    lists:append([
        internal_routes(),
        %% Venture lifecycle (CMD)
        guide_venture_routes:routes(),
        setup_venture_routes:routes(),
        discover_divisions_routes:routes(),
        design_division_routes:routes(),
        plan_division_routes:routes(),
        generate_division_routes:routes(),
        test_division_routes:routes(),
        deploy_division_routes:routes(),
        monitor_division_routes:routes(),
        rescue_division_routes:routes(),
        %% Venture lifecycle (QRY)
        query_ventures_routes:routes(),
        query_discoveries_routes:routes(),
        query_designs_routes:routes(),
        query_plans_routes:routes(),
        query_generations_routes:routes(),
        query_tests_routes:routes(),
        query_deployments_routes:routes(),
        query_monitoring_routes:routes(),
        query_rescues_routes:routes(),
        %% Capabilities
        manage_capabilities_routes:routes(),
        query_capabilities_routes:routes(),
        %% Reputation
        manage_reputation_routes:routes(),
        query_reputation_routes:routes(),
        %% Social
        manage_social_routes:routes(),
        query_social_routes:routes(),
        %% Subscriptions
        manage_subscriptions_routes:routes(),
        query_subscriptions_routes:routes(),
        %% Identities
        manage_identities_routes:routes(),
        query_identities_routes:routes(),
        %% UCAN
        manage_ucan_routes:routes(),
        query_ucan_routes:routes(),
        %% LLM
        serve_llm_routes:routes(),
        %% Connectors
        manage_connectors_routes:routes(),
        %% Mentors
        mentor_agents_routes:routes(),
        query_mentors_routes:routes()
    ]).

%% Routes owned by hecate_api itself (not domain apps).
-spec internal_routes() -> [cowboy_router:route_match()].
internal_routes() ->
    [
        {"/health", hecate_api_health, []},
        {"/api/geo/status", hecate_api_geo, [status]},
        {"/api/geo/reload", hecate_api_geo, [reload]},
        {"/api/geo/check/:ip", hecate_api_geo, [check_ip]},
        {"/api/identity", hecate_api_identity, []},
        {"/api/identity/init", hecate_api_identity, [do_init]},
        {"/api/pairing/start", hecate_api_pairing, [start]},
        {"/api/pairing/status", hecate_api_pairing, [status]},
        {"/api/pairing/cancel", hecate_api_pairing, [cancel]},
        {"/api/agents", hecate_api_agents, [list]},
        {"/api/agents/:agent_id", hecate_api_agents, [get]},
        {"/api/telemetry/cost", hecate_api_telemetry, [total_cost]},
        {"/api/telemetry/cost/:torch_id", hecate_api_telemetry, [cost_by_torch]},
        {"/api/telemetry/cost/:torch_id/cartwheels", hecate_api_telemetry, [cost_by_cartwheel]},
        {"/api/telemetry/cost/:torch_id/agents", hecate_api_telemetry, [cost_by_agent]},
        {"/api/facts/stream", tui_facts_stream_api, []},
        {"/api/rpc/call", call_rpc_api, []}
    ].
