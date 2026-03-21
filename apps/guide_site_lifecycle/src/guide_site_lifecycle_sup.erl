%%% @doc Top-level supervisor for guide_site_lifecycle.
%%%
%%% Empty — site lifecycle is local-only, no emitters or PMs needed yet.
-module(guide_site_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{id => join_code_server,
          start => {join_code_server, start_link, []},
          restart => permanent,
          type => worker}
    ],
    {ok, {SupFlags, Children}}.
