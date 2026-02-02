-module(query_subscriptions_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{
            id => query_subscriptions_store,
            start => {query_subscriptions_store, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => query_subscriptions_subscriber,
            start => {query_subscriptions_subscriber, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {SupFlags, Children}}.
