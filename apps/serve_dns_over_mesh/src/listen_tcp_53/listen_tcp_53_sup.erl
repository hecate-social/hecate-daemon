%%% @doc Supervisor for the TCP/53 listener desk.
-module(listen_tcp_53_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => listen_tcp_53,
          start   => {listen_tcp_53, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [listen_tcp_53]}
    ],
    {ok, {SupFlags, Children}}.
