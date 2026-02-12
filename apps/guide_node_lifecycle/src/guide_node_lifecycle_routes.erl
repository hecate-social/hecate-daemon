-module(guide_node_lifecycle_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        %% Identity
        {"/api/node/identity/register", register_identity_api, []},
        {"/api/node/identity/update", update_identity_api, []},

        %% Capabilities
        {"/api/node/capabilities/announce", announce_capability_api, []},
        {"/api/node/capabilities/:mri/update", update_capability_api, []},
        {"/api/node/capabilities/:mri/retract", retract_capability_api, []},

        %% Mesh connections
        {"/api/node/mesh/connect", connect_node_api, []},
        {"/api/node/mesh/disconnect", disconnect_node_api, []},
        {"/api/node/mesh/endorse", endorse_capability_api, []},
        {"/api/node/mesh/endorsements/revoke", revoke_endorsement_api, []},

        %% Subscriptions
        {"/api/node/subscriptions/subscribe", subscribe_topic_api, []},
        {"/api/node/subscriptions/unsubscribe", unsubscribe_topic_api, []},

        %% UCAN
        {"/api/node/ucan/grant", grant_ucan_api, []},
        {"/api/node/ucan/revoke/:capability_id", revoke_ucan_api, []},

        %% Connectors
        {"/api/node/connectors/register", register_connector_api, []},
        {"/api/node/connectors/:connector_id/revoke", revoke_connector_api, []}
    ].
