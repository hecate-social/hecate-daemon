%%% @doc query_ventures top-level supervisor
-module(query_ventures_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_ventures_store,
            start => {query_ventures_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection desk: venture_setup_v1 -> ventures
        #{
            id => venture_setup_v1_to_ventures_sup,
            start => {venture_setup_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection desk: venture_archived_v1 -> ventures
        #{
            id => venture_archived_v1_to_ventures_sup,
            start => {venture_archived_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
