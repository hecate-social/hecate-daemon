%%% @doc Spoke supervisor for UCAN events listener
%%% SECURITY-CRITICAL: Supervises the listener that handles incoming capability grants/revocations
-module(ucan_events_listener_sup).
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
            id => ucan_events_listener,
            start => {ucan_events_listener, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [ucan_events_listener]
        }
    ],
    {ok, {SupFlags, Children}}.
