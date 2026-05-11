%%% @doc Supervisor for the on_record_observed_invalidate_cache PM.
-module(on_record_observed_invalidate_cache_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => on_record_observed_invalidate_cache,
          start   => {on_record_observed_invalidate_cache, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [on_record_observed_invalidate_cache]}
    ],
    {ok, {SupFlags, Children}}.
