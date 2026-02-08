%%% @doc query_cartwheels top-level supervisor
-module(query_cartwheels_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker
        {query_cartwheels_store,
            {query_cartwheels_store, start_link, []},
            permanent, 5000, worker, [query_cartwheels_store]},

        %% Event subscriber for domain event projections
        {query_cartwheels_subscriber,
            {query_cartwheels_subscriber, start_link, []},
            permanent, 5000, worker, [query_cartwheels_subscriber]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
