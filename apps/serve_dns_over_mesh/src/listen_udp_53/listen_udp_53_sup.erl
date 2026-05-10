%%% @doc Supervisor for the UDP/53 listener desk.
-module(listen_udp_53_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => listen_udp_53,
          start   => {listen_udp_53, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [listen_udp_53]}
    ],
    {ok, {SupFlags, Children}}.
