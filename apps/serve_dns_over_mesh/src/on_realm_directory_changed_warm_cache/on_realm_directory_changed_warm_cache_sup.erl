%%% @doc Supervisor for the warm-cache PM desk.
-module(on_realm_directory_changed_warm_cache_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => on_realm_directory_changed_warm_cache,
          start   => {on_realm_directory_changed_warm_cache, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [on_realm_directory_changed_warm_cache]}
    ],
    {ok, {SupFlags, Children}}.
