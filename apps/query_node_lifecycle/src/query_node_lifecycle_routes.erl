-module(query_node_lifecycle_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        %% Identity queries
        {"/api/node/identities", get_identities_page_api, []},
        {"/api/node/identities/:identity", find_identity_api, []},

        %% Capability queries
        {"/api/node/capabilities", get_capabilities_page_api, []},
        {"/api/node/capabilities/:mri", get_capability_by_mri_api, []},

        %% Mesh connection queries
        {"/api/node/mesh/connections", get_connections_page_api, []},
        {"/api/node/mesh/connected", get_connected_nodes_api, []},
        {"/api/node/mesh/endorsements", get_endorsements_by_node_api, []},
        {"/api/node/mesh/graph", get_mesh_graph_api, []},

        %% Subscription queries
        {"/api/node/subscriptions", get_subscriptions_page_api, []},
        {"/api/node/subscriptions/stats", get_subscription_stats_api, []},

        %% UCAN queries
        {"/api/node/ucan/grants", find_ucan_grants_api, []},
        {"/api/node/ucan/verify", verify_ucan_api, []},
        {"/api/node/ucan/verify/:capability_id", verify_ucan_api, []}
    ].
