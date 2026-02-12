%%% @doc mentor_llms top-level supervisor
%%%
%%% Supervises emitters for the mentor LLMs domain.
-module(mentor_llms_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% Emitters: publish domain events to mesh as integration facts
        {learning_validated_v1_to_mesh,
            {learning_validated_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [learning_validated_v1_to_mesh]},
        {learning_endorsed_v1_to_mesh,
            {learning_endorsed_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [learning_endorsed_v1_to_mesh]},
        {expertise_declared_v1_to_mesh,
            {expertise_declared_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [expertise_declared_v1_to_mesh]},
        {expertise_withdrawn_v1_to_mesh,
            {expertise_withdrawn_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [expertise_withdrawn_v1_to_mesh]}
    ],

    {ok, {SupFlags, Children}}.
