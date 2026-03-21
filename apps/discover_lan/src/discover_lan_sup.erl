%%% @doc Top-level supervisor for discover_lan.
-module(discover_lan_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id => lan_scanner,
          start => {lan_scanner, start_link, []},
          restart => permanent,
          type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, Children}}.
