%%% @doc Supervisor for the positive-cache desk.
-module(cache_positive_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => cache_positive,
          start   => {cache_positive, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [cache_positive]}
    ],
    {ok, {SupFlags, Children}}.
