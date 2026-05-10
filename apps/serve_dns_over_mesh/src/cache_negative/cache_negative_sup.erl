%%% @doc Supervisor for the negative-cache desk.
-module(cache_negative_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => cache_negative,
          start   => {cache_negative, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [cache_negative]}
    ],
    {ok, {SupFlags, Children}}.
