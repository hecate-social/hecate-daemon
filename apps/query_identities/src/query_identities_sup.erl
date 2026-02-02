-module(query_identities_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{
            id => query_identities_store,
            start => {query_identities_store, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => query_identities_subscriber,
            start => {query_identities_subscriber, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Listener spoke for remote identities (discovery, direct projection)
        #{
            id => remote_identities_listener_sup,
            start => {remote_identities_listener_sup, start_link, []},
            restart => permanent,
            shutdown => infinity,
            type => supervisor
        }
    ],
    {ok, {SupFlags, Children}}.
