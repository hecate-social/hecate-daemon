%%% @doc Supervisor for the cache_records desk.
%%%
%%% Three workers:
%%%   - cache_records: ETS owner (one named table per cache layer L1..L5)
%%%   - cache_invalidate: invalidation orchestration
%%%   - cache_ttl_sweep: periodic TTL fallback eviction
-module(cache_records_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => cache_records,
          start   => {cache_records, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [cache_records]},
        #{id      => cache_invalidate,
          start   => {cache_invalidate, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [cache_invalidate]},
        #{id      => cache_ttl_sweep,
          start   => {cache_ttl_sweep, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [cache_ttl_sweep]}
    ],
    {ok, {SupFlags, Children}}.
