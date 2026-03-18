%%% @doc Top-level supervisor for project_briefcase (PRJ).
%%%
%%% Starts the ETS store first (creates tables), then all projections.
%%% @end
-module(project_briefcase_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    StoreOpts = #{store_id => briefcase_store},
    Projections = [
        folder_lifecycle_to_tree,
        file_lifecycle_to_index
    ],
    Children = [
        #{
            id => project_briefcase_store,
            start => {project_briefcase_store, start_link, []},
            restart => permanent,
            type => worker
        }
        | [#{
            id => Mod,
            start => {evoq_projection, start_link, [Mod, #{}, StoreOpts]},
            restart => permanent,
            type => worker
        } || Mod <- Projections]
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
