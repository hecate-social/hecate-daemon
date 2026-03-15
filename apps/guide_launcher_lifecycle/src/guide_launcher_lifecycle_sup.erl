%%% @doc guide_launcher_lifecycle top-level supervisor
%%%
%%% Supervises all emitters, process managers, and the launcher initializer:
%%% - PG emitters: subscribe to evoq, broadcast to pg groups (internal)
%%% - Process managers: react to plugin events, register/unregister entries
%%% - Launcher initializer: ensures launcher aggregate exists on startup
%%% @end
-module(guide_launcher_lifecycle_sup).
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

        emitter(entry_registered_v1_to_pg),
        emitter(entry_unregistered_v1_to_pg),
        emitter(launcher_reorganized_v1_to_pg),

        %% -- Process Managers (cross-domain, react to plugin events) --
        %% Started via evoq_event_handler — auto-registers with event type registry

        emitter(on_plugin_installed_register_entry),
        emitter(on_plugin_removed_unregister_entry),

        %% -- Launcher initializer (ensures birth event on startup) --

        #{id => launcher_initializer,
          start => {launcher_initializer, start_link, []},
          restart => transient, type => worker}
    ],

    {ok, {SupFlags, Children}}.

emitter(Mod) ->
    #{id => Mod, start => {evoq_event_handler, start_link, [Mod, #{}]},
      restart => permanent, type => worker}.
