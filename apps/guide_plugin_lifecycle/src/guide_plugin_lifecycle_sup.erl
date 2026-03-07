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

        %% -- Container pull emitters --

        #{id => container_pull_started_v1_to_pg,
          start => {evoq_event_handler, start_link, [container_pull_started_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => container_pull_cancelled_v1_to_pg,
          start => {evoq_event_handler, start_link, [container_pull_cancelled_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => container_pull_completed_v1_to_pg,
          start => {evoq_event_handler, start_link, [container_pull_completed_v1_to_pg, #{}]},
          restart => permanent, type => worker},

        %% -- Container confirmation emitters --

        #{id => container_confirmed_up_v1_to_pg,
          start => {evoq_event_handler, start_link, [container_confirmed_up_v1_to_pg, #{}]},
          restart => permanent, type => worker},
        #{id => container_confirmed_down_v1_to_pg,
          start => {evoq_event_handler, start_link, [container_confirmed_down_v1_to_pg, #{}]},
          restart => permanent, type => worker},

        %% -- Pull PM (runs podman pull, provisions .container) --

        #{id => on_container_pull_started_pull_image,
          start => {on_container_pull_started_pull_image, start_link, []},
          restart => permanent, type => worker},

        %% -- Container health watcher (dispatches confirm up/down) --

        #{id => plugin_container_watcher,
          start => {plugin_container_watcher, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
