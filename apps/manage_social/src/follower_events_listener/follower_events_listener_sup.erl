%%% @doc Spoke supervisor for follower events listener
-module(follower_events_listener_sup).
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
            id => follower_events_listener,
            start => {follower_events_listener, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [follower_events_listener]
        }
    ],
    {ok, {SupFlags, Children}}.
