%%% @doc Desk supervisor for remote_learning_listener
-module(remote_learning_listener_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => remote_learning_listener,
            start => {remote_learning_listener, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [remote_learning_listener]
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, Children}}.
