-module(hecate_api_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    %% Get HTTP configuration
    Port = application:get_env(hecate_api, http_port, 4444),

    %% Define Cowboy routes
    Dispatch = cowboy_router:compile([
        {'_', [
            %% Health check
            {"/health", hecate_api_health, []},

            %% Identity
            {"/identity", hecate_api_identity, []},
            {"/identity/init", hecate_api_identity, [do_init]},

            %% Pairing
            {"/api/pairing/start", hecate_api_pairing, [start]},
            {"/api/pairing/status", hecate_api_pairing, [status]},
            {"/api/pairing/cancel", hecate_api_pairing, [cancel]},

            %% Capabilities
            {"/capabilities/announce", hecate_api_capabilities, [announce]},
            {"/capabilities/discover", hecate_api_capabilities, [discover]},
            {"/capabilities/:mri", hecate_api_capabilities, [get]},
            {"/capabilities/:mri/update", hecate_api_capabilities, [update]},
            {"/capabilities/:mri/retract", hecate_api_capabilities, [retract]},

            %% Reputation
            {"/reputation/:agent_identity", hecate_api_reputation, [get]},
            {"/rpc-calls", hecate_api_reputation, [list_calls]},
            {"/disputes", hecate_api_reputation, [list_disputes]},

            %% RPC (tracking for reputation)
            {"/rpc/track", hecate_api_rpc, [track]},

            %% Social
            {"/social/follow", hecate_api_social, [follow]},
            {"/social/unfollow", hecate_api_social, [unfollow]},
            {"/social/endorse", hecate_api_social, [endorse]},
            {"/social/endorsement/revoke", hecate_api_social, [revoke_endorsement]},
            {"/social/followers/:agent_identity", hecate_api_social, [get_followers]},
            {"/social/following/:agent_identity", hecate_api_social, [get_following]},
            {"/social/endorsements/:agent_identity", hecate_api_social, [get_endorsements]},
            {"/social/graph/:agent_identity", hecate_api_social, [get_social_graph]},

            %% Subscriptions
            {"/subscriptions", hecate_api_subscriptions, [list]},
            {"/subscriptions/subscribe", hecate_api_subscriptions, [subscribe]},
            {"/subscriptions/unsubscribe", hecate_api_subscriptions, [unsubscribe]},
            {"/subscriptions/stats", hecate_api_subscriptions, [stats]},

            %% Identities
            {"/agents", hecate_api_identities, [list]},
            {"/agents/register", hecate_api_identities, [register]},
            {"/agents/:agent_identity", hecate_api_identities, [get]},
            {"/agents/:agent_identity/update", hecate_api_identities, [update]},

            %% UCAN
            {"/ucan/grant", hecate_api_ucan, [grant]},
            {"/ucan/revoke/:capability_id", hecate_api_ucan, [revoke]},
            {"/ucan/capabilities", hecate_api_ucan, [list]},
            {"/ucan/verify/:capability_id", hecate_api_ucan, [verify]},
            {"/ucan/verify", hecate_api_ucan, [verify_action]},

            %% LLM
            {"/api/llm/models", hecate_api_llm, [models]},
            {"/api/llm/chat", hecate_api_llm, [chat]},
            {"/api/llm/health", hecate_api_llm, [health]}
        ]}
    ]),

    %% Start Cowboy HTTP listener
    {ok, _} = cowboy:start_clear(hecate_http_listener,
        [{port, Port}],
        #{env => #{dispatch => Dispatch}}
    ),

    io:format("~n🗝️  Hecate API listening on http://127.0.0.1:~p~n~n", [Port]),

    hecate_api_sup:start_link().

stop(_State) ->
    ok = cowboy:stop_listener(hecate_http_listener),
    ok.
