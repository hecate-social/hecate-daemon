%%% @doc Top-level supervisor for guide_node_lifecycle.
%%%
%%% Supervises mesh emitters, process managers, and connector lifecycle.
%%% Does NOT create event stores — uses shared hecate_event_store.
-module(guide_node_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% === Identity emitters (2) ===
        worker(identity_registered_v1_to_mesh),
        worker(identity_updated_v1_to_mesh),

        %% === Capability emitters (3) ===
        worker(capability_announced_v1_to_mesh),
        worker(capability_updated_v1_to_mesh),
        worker(capability_retracted_v1_to_mesh),

        %% === Capability PMs (3) ===
        worker(on_llm_detected_announce_capability),
        worker(on_llm_removed_retract_capability),
        worker(on_llm_status_reported_update_capability),

        %% === Mesh connection emitters (4) ===
        worker(node_connected_v1_to_mesh),
        worker(node_disconnected_v1_to_mesh),
        worker(capability_endorsed_v1_to_mesh),
        worker(endorsement_revoked_v1_to_mesh),

        %% === Subscription emitters (2) ===
        worker(topic_subscribed_v1_to_mesh),
        worker(topic_unsubscribed_v1_to_mesh),

        %% === UCAN emitters (2) ===
        worker(ucan_granted_v1_to_mesh),
        worker(ucan_revoked_v1_to_mesh),

        %% === Connector PM (1) ===
        worker(on_connector_registered_start_listener)
    ],

    {ok, {SupFlags, Children}}.

%% Internal helper
worker(Module) ->
    {Module, {Module, start_link, []}, permanent, 5000, worker, [Module]}.
