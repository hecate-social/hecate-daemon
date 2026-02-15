%%% @doc Desk supervisor for mentor_discovery_listener
-module(mentor_discovery_listener_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => mentor_discovery_listener,
            start => {mentor_discovery_listener, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [mentor_discovery_listener]
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, Children}}.
