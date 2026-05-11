%%% @doc Supervisor for the trust_anchors desk.
-module(trust_anchors_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => trust_anchors,
          start   => {trust_anchors, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [trust_anchors]}
    ],
    {ok, {SupFlags, Children}}.
