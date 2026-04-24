%%% @doc Top-level supervisor for project_site (PRJ).
%%%
%%% Starts the ETS stores first (creates tables), then the projections.
%%% @end
-module(project_site_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% ETS stores (must start first — create tables)
        #{id => project_site_store,
          start => {project_site_store, start_link, []},
          restart => permanent, type => worker},
        #{id => project_lan_machines_store,
          start => {project_lan_machines_store, start_link, []},
          restart => permanent, type => worker},
        %% Merged projection: all site lifecycle events -> site ETS
        #{id => site_lifecycle_to_site,
          start => {evoq_projection, start_link, [site_lifecycle_to_site, #{}, #{store_id => site_store}]},
          restart => permanent, type => worker},
        %% LAN observations -> lan_machines ETS (per-observer)
        #{id => lan_machine_spotted_v1_to_lan_machines,
          start => {evoq_projection, start_link, [lan_machine_spotted_v1_to_lan_machines, #{}, #{store_id => site_store}]},
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
