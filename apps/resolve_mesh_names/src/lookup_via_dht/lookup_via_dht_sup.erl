%%% @doc Supervisor for the lookup_via_dht desk.
%%%
%%% Two workers:
%%%   - lookup_via_dht: macula:find_record wrapper + retry loop
%%%   - lookup_dedup: in-flight ETS de-dup registry
-module(lookup_via_dht_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => lookup_dedup,
          start   => {lookup_dedup, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [lookup_dedup]},
        #{id      => lookup_via_dht,
          start   => {lookup_via_dht, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [lookup_via_dht]}
    ],
    {ok, {SupFlags, Children}}.
