%%% @doc Top-level supervisor for project_plugins (PRJ).
%%%
%%% Supervises the plugins read model store and all projection desks.
%%% Each projection writes to a shared named ETS table (plugins).
%%% @end
-module(project_plugins_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    StoreOpts = #{store_id => plugins_store},
    Children = [
        %% Read model query facade (must start first — creates ETS table)
        #{
            id => project_plugins_store,
            start => {project_plugins_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Merged projection: all plugin lifecycle events -> plugins ETS
        %% Single projection eliminates race conditions between separate
        %% projections competing for the same ETS table.
        #{
            id => plugin_lifecycle_to_plugins,
            start => {evoq_projection, start_link, [plugin_lifecycle_to_plugins, #{}, StoreOpts]},
            restart => permanent,
            type => worker
        }
    ] ++ web_emitters(StoreOpts),
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.

%% Per-event emitters: broadcast plugin status changes to web SSE clients.
%% Each event type gets its own emitter (no god modules).
web_emitters(StoreOpts) ->
    Modules = [
        plugin_installed_v1_to_web,
        plugin_upgraded_v1_to_web,
        plugin_removed_v1_to_web,
        plugin_execution_requested_v1_to_web,
        plugin_termination_requested_v1_to_web,
        container_confirmed_up_v1_to_web,
        container_confirmed_down_v1_to_web,
        oci_pull_started_v1_to_web,
        oci_pull_cancelled_v1_to_web,
        oci_pull_completed_v1_to_web,
        plugin_package_extracted_v1_to_web,
        plugin_load_confirmed_v1_to_web,
        plugin_unload_confirmed_v1_to_web
    ],
    [#{
        id => M,
        start => {evoq_event_handler, start_link, [M, #{}, StoreOpts]},
        restart => permanent,
        type => worker
    } || M <- Modules].
