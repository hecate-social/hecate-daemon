%%% @doc Supervisor for the TCP/53 listener desk.
-module(listen_tcp_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => listen_tcp,
          start   => {listen_tcp, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [listen_tcp]}
    ],
    {ok, {SupFlags, Children}}.
