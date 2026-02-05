%%% @doc query_alc top-level supervisor
-module(query_alc_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker
        {query_alc_store,
            {query_alc_store, start_link, []},
            permanent, 5000, worker, [query_alc_store]},

        %% Event subscriber for domain event projections
        {query_alc_subscriber,
            {query_alc_subscriber, start_link, []},
            permanent, 5000, worker, [query_alc_subscriber]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
