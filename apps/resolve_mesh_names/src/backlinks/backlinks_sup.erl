%%% @doc Supervisor for the backlinks desk.
-module(backlinks_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => backlinks,
          start   => {backlinks, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [backlinks]}
    ],
    {ok, {SupFlags, Children}}.
