-module(query_node_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% SQLite store (must start first)
        #{id => query_node_lifecycle_store,
          start => {query_node_lifecycle_store, start_link, []},
          restart => permanent, type => worker},

        %% Event subscriber (routes domain events to projection modules)
        #{id => query_node_lifecycle_subscriber,
          start => {query_node_lifecycle_subscriber, start_link, []},
          restart => permanent, type => worker},

        %% Mesh listener desks (6 — project inbound facts to remote_* tables)
        #{id => remote_identities_listener_sup,
          start => {remote_identities_listener_sup, start_link, []},
          restart => permanent, shutdown => infinity, type => supervisor},
        #{id => remote_capabilities_listener_sup,
          start => {remote_capabilities_listener_sup, start_link, []},
          restart => permanent, shutdown => infinity, type => supervisor},
        #{id => mesh_connection_listener_sup,
          start => {mesh_connection_listener_sup, start_link, []},
          restart => permanent, shutdown => infinity, type => supervisor},
        #{id => mesh_endorsement_listener_sup,
          start => {mesh_endorsement_listener_sup, start_link, []},
          restart => permanent, shutdown => infinity, type => supervisor},
        #{id => mesh_subscription_listener_sup,
          start => {mesh_subscription_listener_sup, start_link, []},
          restart => permanent, shutdown => infinity, type => supervisor},
        #{id => mesh_ucan_listener_sup,
          start => {mesh_ucan_listener_sup, start_link, []},
          restart => permanent, shutdown => infinity, type => supervisor},

        %% Latency measurement for remote capabilities
        #{id => measure_remote_latency,
          start => {measure_remote_latency, start_link, []},
          restart => permanent, type => worker}
    ],
    {ok, {SupFlags, Children}}.
