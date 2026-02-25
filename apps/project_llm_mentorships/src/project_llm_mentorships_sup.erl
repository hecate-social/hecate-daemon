%%% @doc project_llm_mentorships top-level supervisor
-module(project_llm_mentorships_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker
        {project_llm_mentorships_store,
            {project_llm_mentorships_store, start_link, []},
            permanent, 5000, worker, [project_llm_mentorships_store]},

        %% Event subscriber for domain event projections
        {project_llm_mentorships_subscriber,
            {project_llm_mentorships_subscriber, start_link, []},
            permanent, 5000, worker, [project_llm_mentorships_subscriber]},

        %% Listener desks for remote facts from mesh
        {remote_learning_listener_sup,
            {remote_learning_listener_sup, start_link, []},
            permanent, infinity, supervisor, [remote_learning_listener_sup]},
        {mentor_discovery_listener_sup,
            {mentor_discovery_listener_sup, start_link, []},
            permanent, infinity, supervisor, [mentor_discovery_listener_sup]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
