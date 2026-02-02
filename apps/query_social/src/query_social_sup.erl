-module(query_social_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% SQLite store for social graph read models
        #{
            id => query_social_store,
            start => {query_social_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Event subscriber for automatic projections
        #{
            id => query_social_subscriber,
            start => {query_social_subscriber, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {SupFlags, Children}}.
