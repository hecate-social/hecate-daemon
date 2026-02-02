%%% @doc Spoke supervisor for remote capabilities listener
-module(remote_capabilities_listener_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },
    Children = [
        #{
            id => remote_capabilities_listener,
            start => {remote_capabilities_listener, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [remote_capabilities_listener]
        }
    ],
    {ok, {SupFlags, Children}}.
