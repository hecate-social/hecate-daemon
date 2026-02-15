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
        %% Venture lifecycle (4 consolidated apps)
        guide_venture_lifecycle_routes:routes(),
        query_venture_lifecycle_routes:routes(),
        guide_division_alc_routes:routes(),
        query_division_alc_routes:routes(),
        %% Node lifecycle (2 consolidated apps — was 11 node ops apps)
        guide_node_lifecycle_routes:routes(),
        query_node_lifecycle_routes:routes(),
        %% Mentorships (renamed from mentor_agents + query_mentors)
        mentor_llms_routes:routes(),
        query_mentorships_routes:routes(),
        %% LLM
        serve_llm_routes:routes(),
        %% IRC (P2P chat)
        manage_irc_routes:routes(),
        query_irc_routes:routes(),
        %% Arcade — Snake Duel
        run_snake_duel_routes:routes(),
        query_snake_duel_routes:routes(),
        %% Arcade — Snake Gladiators
        breed_snake_gladiators_routes:routes(),
        query_snake_gladiators_routes:routes()
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
        {"/api/telemetry/cost/:venture_id", hecate_api_telemetry, [cost_by_venture]},
        {"/api/telemetry/cost/:venture_id/divisions", hecate_api_telemetry, [cost_by_division]},
        {"/api/telemetry/cost/:venture_id/agents", hecate_api_telemetry, [cost_by_agent]},
        {"/api/facts/stream", tui_facts_stream_api, []},
        {"/api/rpc/call", call_rpc_api, []}
    ].
