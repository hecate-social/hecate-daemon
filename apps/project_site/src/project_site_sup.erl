%%% @doc Top-level supervisor for project_site (PRJ).
%%%
%%% Starts the ETS store first (creates table), then the merged projection.
%%% @end
-module(project_site_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% ETS store (must start first — creates table)
        #{id => project_site_store,
          start => {project_site_store, start_link, []},
          restart => permanent, type => worker},
        %% Merged projection: all site lifecycle events -> site ETS
        #{id => site_lifecycle_to_site,
          start => {evoq_projection, start_link, [site_lifecycle_to_site, #{}, #{store_id => site_store}]},
          restart => permanent, type => worker},
        %% Web emitters: push site changes to frontend via SSE
        #{id => site_initiated_v1_to_web,
          start => {evoq_event_handler, start_link, [site_initiated_v1_to_web, #{}, #{store_id => site_store}]},
          restart => permanent, type => worker},
        #{id => node_admitted_v1_to_web,
          start => {evoq_event_handler, start_link, [node_admitted_v1_to_web, #{}, #{store_id => site_store}]},
          restart => permanent, type => worker},
        #{id => node_removed_v1_to_web,
          start => {evoq_event_handler, start_link, [node_removed_v1_to_web, #{}, #{store_id => site_store}]},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
