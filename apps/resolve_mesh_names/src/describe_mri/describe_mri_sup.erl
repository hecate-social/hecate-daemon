%%% @doc Supervisor for the describe_mri desk.
-module(describe_mri_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => describe_mri,
          start   => {describe_mri, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [describe_mri]}
    ],
    {ok, {SupFlags, Children}}.
