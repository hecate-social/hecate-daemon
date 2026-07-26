%%% @doc Top-level supervisor for project_mesh_activity (PRJ).
%%%
%%% Order: ETS store first (creates `mesh_activity' named table), then
%%% the two projections — one subscribed to mesh_publications_store, the
%%% other to mesh_artifacts_store. Both write into the same ETS.
-module(project_mesh_activity_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% ETS owner: creates `mesh_activity' named table.
        #{id => project_mesh_activity_store,
          start => {project_mesh_activity_store, start_link, []},
          restart => permanent, type => worker},

        %% Projection: domain events from mesh_publications_store.
        #{id => mesh_fact_published_v1_to_mesh_activity,
          start => {evoq_projection, start_link,
                    [mesh_fact_published_v1_to_mesh_activity, #{},
                     #{store_id => mesh_publications_store}]},
          restart => permanent, type => worker},

        %% Projection: domain events from mesh_artifacts_store.
        #{id => mesh_artifact_shared_v1_to_mesh_activity,
          start => {evoq_projection, start_link,
                    [mesh_artifact_shared_v1_to_mesh_activity, #{},
                     #{store_id => mesh_artifacts_store}]},
          restart => permanent, type => worker},

        %% Projection: domain events from mesh_inbox_store (inbound).
        #{id => mesh_fact_received_v1_to_mesh_activity,
          start => {evoq_projection, start_link,
                    [mesh_fact_received_v1_to_mesh_activity, #{},
                     #{store_id => mesh_inbox_store}]},
          restart => permanent, type => worker},

        %% Projection: subscription roster (mesh_subscriptions ETS).
        #{id => mesh_subscriptions_lifecycle_to_subscription_list,
          start => {evoq_projection, start_link,
                    [mesh_subscriptions_lifecycle_to_subscription_list, #{},
                     #{store_id => mesh_subscriptions_store}]},
          restart => permanent, type => worker}
    ],
    {ok, {SupFlags, Children}}.
