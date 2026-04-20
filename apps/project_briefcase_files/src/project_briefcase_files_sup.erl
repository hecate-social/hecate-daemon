%%% @doc Top-level supervisor for project_briefcase_files (PRJ).
%%%
%%% Starts the ETS store first (creates `briefcase_files` table), then
%%% the merged projection that consumes briefcase lifecycle events from
%%% the `briefcase_store` event log.
%%% @end
-module(project_briefcase_files_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% ETS store (must start first — creates table)
        #{id      => project_briefcase_files_store,
          start   => {project_briefcase_files_store, start_link, []},
          restart => permanent,
          type    => worker},
        %% Merged projection: briefcase lifecycle events -> files ETS
        #{id      => briefcase_lifecycle_to_files,
          start   => {evoq_projection, start_link,
                      [briefcase_lifecycle_to_files, #{},
                       #{store_id => briefcase_store}]},
          restart => permanent,
          type    => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
