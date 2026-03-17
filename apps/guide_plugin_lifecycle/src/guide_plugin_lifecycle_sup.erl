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

        emitter(plugin_installed_v1_to_pg),
        emitter(plugin_upgraded_v1_to_pg),
        emitter(plugin_removed_v1_to_pg),
        emitter(plugin_execution_requested_v1_to_pg),
        emitter(plugin_termination_requested_v1_to_pg),

        %% -- Process Managers (side effects) --
        %% evoq_event_handler PMs: auto-register with event type registry

        emitter(on_plugin_upgraded_update_container),
        emitter(on_plugin_upgraded_reload_in_vm),
        emitter(on_plugin_removed_deprovision_container),
        emitter(on_plugin_removed_unload_in_vm),

        %% -- Execution request PMs (split by plugin type) --

        emitter(on_plugin_execution_requested_start_container),
        emitter(on_plugin_execution_requested_start_in_vm),

        %% -- Termination request PMs (split by plugin type) --

        emitter(on_plugin_termination_requested_stop_container),
        emitter(on_plugin_termination_requested_stop_in_vm),

        %% -- OCI pull emitters --

        emitter(oci_pull_started_v1_to_pg),
        emitter(oci_pull_cancelled_v1_to_pg),
        emitter(oci_pull_completed_v1_to_pg),

        %% -- Container confirmation emitters --

        emitter(container_confirmed_up_v1_to_pg),
        emitter(container_confirmed_down_v1_to_pg),

        %% -- OCI Pull PMs --

        emitter(on_plugin_installed_start_oci_pull),
        #{id => on_oci_pull_started_pull_image,
          start => {on_oci_pull_started_pull_image, start_link, []},
          restart => permanent, type => worker},

        %% -- Container health watcher (dispatches confirm up/down) --

        #{id => plugin_container_watcher,
          start => {plugin_container_watcher, start_link, []},
          restart => permanent, type => worker},

        %% -- In-VM plugin emitters --

        emitter(plugin_package_extracted_v1_to_pg),
        emitter(plugin_load_confirmed_v1_to_pg),
        emitter(plugin_unload_confirmed_v1_to_pg),

        %% -- In-VM plugin process managers --

        emitter(on_plugin_installed_extract_package),
        emitter(on_plugin_package_extracted_request_execution)
    ],

    {ok, {SupFlags, Children}}.

emitter(Mod) ->
    #{id => Mod, start => {evoq_event_handler, start_link, [Mod, #{}]},
      restart => permanent, type => worker}.
