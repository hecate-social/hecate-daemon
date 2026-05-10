%%% @doc Supervisor for the refresh-authority desk.
-module(refresh_authority_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id      => refresh_authority,
          start   => {refresh_authority, start_link, []},
          restart => permanent,
          type    => worker,
          modules => [refresh_authority]}
    ],
    {ok, {SupFlags, Children}}.
