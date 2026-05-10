%%% @doc Supervisor for the DHT-lookup desk. Two workers: the
%%% lookup gen_server itself and the in-flight de-dup ETS owner.
-module(lookup_record_in_dht_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => lookup_record_dedup,
          start   => {lookup_record_dedup, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [lookup_record_dedup]},
        #{id      => lookup_record_in_dht,
          start   => {lookup_record_in_dht, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [lookup_record_in_dht]}
    ],
    {ok, {SupFlags, Children}}.
