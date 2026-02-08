%%% @doc query_torches top-level supervisor
-module(query_torches_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker
        {query_torches_store,
            {query_torches_store, start_link, []},
            permanent, 5000, worker, [query_torches_store]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
