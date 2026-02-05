%%% @doc query_mentors top-level supervisor
-module(query_mentors_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker
        {query_mentors_store,
            {query_mentors_store, start_link, []},
            permanent, 5000, worker, [query_mentors_store]},

        %% Event subscriber for domain event projections
        {query_mentors_subscriber,
            {query_mentors_subscriber, start_link, []},
            permanent, 5000, worker, [query_mentors_subscriber]},

        %% Listener spokes for remote facts from mesh
        {remote_learning_listener_sup,
            {remote_learning_listener_sup, start_link, []},
            permanent, infinity, supervisor, [remote_learning_listener_sup]},
        {mentor_discovery_listener_sup,
            {mentor_discovery_listener_sup, start_link, []},
            permanent, infinity, supervisor, [mentor_discovery_listener_sup]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
