%%% @doc Supervisor for the DoH listener desk.
-module(listen_doh_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => listen_doh,
          start   => {listen_doh, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [listen_doh]}
    ],
    {ok, {SupFlags, Children}}.
