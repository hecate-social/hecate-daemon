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
          start => {plugin_installed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => plugin_upgraded_v1_to_pg,
          start => {plugin_upgraded_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => plugin_removed_v1_to_pg,
          start => {plugin_removed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% -- Process Managers (side effects) --

        #{id => on_plugin_installed_provision_container,
          start => {on_plugin_installed_provision_container, start_link, []},
          restart => permanent, type => worker},
        #{id => on_plugin_upgraded_update_container,
          start => {on_plugin_upgraded_update_container, start_link, []},
          restart => permanent, type => worker},
        #{id => on_plugin_removed_deprovision_container,
          start => {on_plugin_removed_deprovision_container, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
