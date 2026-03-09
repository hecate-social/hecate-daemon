%%% @doc guide_plugin_lifecycle top-level supervisor
%%%
%%% Supervises all emitters and process managers for plugin lifecycle:
%%% - PG emitters: subscribe to evoq, broadcast to pg groups (internal)
%%% - Process managers: react to events, perform side effects
%%% @end
-module(guide_plugin_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% -- PG emitters (internal, subscribe via evoq -> broadcast to pg) --

        #{id => plugin_installed_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_installed_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => plugin_upgraded_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_upgraded_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => plugin_removed_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_removed_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => plugin_execution_started_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_execution_started_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => plugin_execution_stopped_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_execution_stopped_v1_to_pg, #{}]},
          restart => permanent, type => worker},

        %% -- Process Managers (side effects) --
        %% evoq_event_handler PMs: auto-register with event type registry

        #{id => on_plugin_upgraded_update_container,
          start => {evoq_event_handler, start_link, [on_plugin_upgraded_update_container, #{}]},
          restart => permanent, type => worker},
        #{id => on_plugin_removed_deprovision_container,
          start => {evoq_event_handler, start_link, [on_plugin_removed_deprovision_container, #{}]},
          restart => permanent, type => worker},

        %% gen_server PMs: kept as gen_server due to handle_info patterns
        %% (reconcile timers, pg cancel messages, pull progress/done messages)
        %% evoq_event_handler drops all handle_info messages, so these cannot be converted.

        #{id => on_plugin_execution_started_start_container,
          start => {on_plugin_execution_started_start_container, start_link, []},
          restart => permanent, type => worker},
        #{id => on_plugin_execution_stopped_stop_container,
          start => {evoq_event_handler, start_link, [on_plugin_execution_stopped_stop_container, #{}]},
          restart => permanent, type => worker},

        %% -- OCI pull emitters --

        #{id => oci_pull_started_v1_to_pg,
          start => {evoq_event_handler, start_link, [oci_pull_started_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => oci_pull_cancelled_v1_to_pg,
          start => {evoq_event_handler, start_link, [oci_pull_cancelled_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => oci_pull_completed_v1_to_pg,
          start => {evoq_event_handler, start_link, [oci_pull_completed_v1_to_pg, #{}]},
          restart => permanent, type => worker},

        %% -- Container confirmation emitters --

        #{id => container_confirmed_up_v1_to_pg,
          start => {evoq_event_handler, start_link, [container_confirmed_up_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => container_confirmed_down_v1_to_pg,
          start => {evoq_event_handler, start_link, [container_confirmed_down_v1_to_pg, #{}]},
          restart => permanent, type => worker},

        %% -- OCI Pull PMs --

        #{id => on_plugin_installed_start_oci_pull,
          start => {evoq_event_handler, start_link, [on_plugin_installed_start_oci_pull, #{}]},
          restart => permanent, type => worker},
        #{id => on_oci_pull_started_pull_image,
          start => {on_oci_pull_started_pull_image, start_link, []},
          restart => permanent, type => worker},

        %% -- Container health watcher (dispatches confirm up/down) --

        #{id => plugin_container_watcher,
          start => {plugin_container_watcher, start_link, []},
          restart => permanent, type => worker},

        %% -- In-VM plugin emitters --

        #{id => plugin_package_extracted_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_package_extracted_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => plugin_activated_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_activated_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => plugin_deactivated_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_deactivated_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => plugin_load_confirmed_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_load_confirmed_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => plugin_unload_confirmed_v1_to_pg,
          start => {evoq_event_handler, start_link, [plugin_unload_confirmed_v1_to_pg, #{}]},
          restart => permanent, type => worker},

        %% -- In-VM plugin process managers --

        #{id => on_plugin_installed_extract_package,
          start => {evoq_event_handler, start_link, [on_plugin_installed_extract_package, #{}]},
          restart => permanent, type => worker},
        #{id => on_plugin_package_extracted_activate_plugin,
          start => {evoq_event_handler, start_link, [on_plugin_package_extracted_activate_plugin, #{}]},
          restart => permanent, type => worker},
        #{id => on_plugin_activated_load_plugin,
          start => {evoq_event_handler, start_link, [on_plugin_activated_load_plugin, #{}]},
          restart => permanent, type => worker},
        #{id => on_plugin_deactivated_unload_plugin,
          start => {evoq_event_handler, start_link, [on_plugin_deactivated_unload_plugin, #{}]},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
