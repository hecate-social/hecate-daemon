%%% @doc query_capabilities top-level supervisor
-module(query_capabilities_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection pool worker
        {query_capabilities_store,
            {query_capabilities_store, start_link, []},
            permanent, 5000, worker, [query_capabilities_store]},

        %% Event subscriber for automatic projections (internal domain events)
        %% Handles capability_announced_v1, capability_retracted_v1 (including LLM capabilities)
        {query_capabilities_subscriber,
            {query_capabilities_subscriber, start_link, []},
            permanent, 5000, worker, [query_capabilities_subscriber]},

        %% Listener spoke for remote capabilities (discovery, direct projection)
        {remote_capabilities_listener_sup,
            {remote_capabilities_listener_sup, start_link, []},
            permanent, infinity, supervisor, [remote_capabilities_listener_sup]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
