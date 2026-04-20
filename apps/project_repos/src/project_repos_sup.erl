%%% @doc Top-level supervisor for project_repos (PRJ).
%%%
%%% Starts the ETS store (creates the `repos` read-model table), then
%%% the merged projection consuming local repo lifecycle events. A
%%% future mesh subscriber will fold cross-realm catalog facts in.
%%% @end
-module(project_repos_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id      => project_repos_store,
          start   => {project_repos_store, start_link, []},
          restart => permanent,
          type    => worker},
        #{id      => repo_lifecycle_to_repos,
          start   => {evoq_projection, start_link,
                      [repo_lifecycle_to_repos, #{},
                       #{store_id => repo_store}]},
          restart => permanent,
          type    => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
