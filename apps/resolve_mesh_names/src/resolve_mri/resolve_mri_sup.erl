%%% @doc Supervisor for the resolve_mri desk.
-module(resolve_mri_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => resolve_mri,
          start   => {resolve_mri, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [resolve_mri]}
    ],
    {ok, {SupFlags, Children}}.
