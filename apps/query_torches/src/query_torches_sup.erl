%%% @doc query_torches top-level supervisor
-module(query_torches_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_torches_store,
            start => {query_torches_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection spoke: torch_initiated_v1 -> torches
        #{
            id => torch_initiated_v1_to_torches_sup,
            start => {torch_initiated_v1_to_torches_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection spoke: torch_archived_v1 -> torches (updates status with ARCHIVED flag)
        #{
            id => torch_archived_v1_to_torches_sup,
            start => {torch_archived_v1_to_torches_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
