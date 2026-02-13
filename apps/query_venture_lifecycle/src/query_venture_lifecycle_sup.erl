%%% @doc Top-level supervisor for query_venture_lifecycle.
-module(query_venture_lifecycle_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_venture_lifecycle_store,
            start => {query_venture_lifecycle_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: venture_initiated_v1 -> ventures table
        #{
            id => venture_initiated_v1_to_ventures_sup,
            start => {venture_initiated_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: vision_refined_v1 -> ventures table
        #{
            id => vision_refined_v1_to_ventures_sup,
            start => {vision_refined_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: vision_submitted_v1 -> ventures table
        #{
            id => vision_submitted_v1_to_ventures_sup,
            start => {vision_submitted_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: venture_archived_v1 -> ventures table
        #{
            id => venture_archived_v1_to_ventures_sup,
            start => {venture_archived_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: discovery_started_v1 -> ventures table
        #{
            id => discovery_started_v1_to_ventures_sup,
            start => {discovery_started_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: division_identified_v1 -> discovered_divisions table
        #{
            id => division_identified_v1_to_discovered_divisions_sup,
            start => {division_identified_v1_to_discovered_divisions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: discovery_completed_v1 -> ventures table
        #{
            id => discovery_completed_v1_to_ventures_sup,
            start => {discovery_completed_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: discovery_paused_v1 -> ventures table
        #{
            id => discovery_paused_v1_to_ventures_sup,
            start => {discovery_paused_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: discovery_resumed_v1 -> ventures table
        #{
            id => discovery_resumed_v1_to_ventures_sup,
            start => {discovery_resumed_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },

        %% ── Big Picture Event Storming projections ──────────────────────

        %% Projection: big_picture_storm_started_v1 -> storm_sessions table
        #{
            id => big_picture_storm_started_v1_to_storm_sessions_sup,
            start => {big_picture_storm_started_v1_to_storm_sessions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: storm_phase_advanced_v1 -> storm_sessions table
        #{
            id => storm_phase_advanced_v1_to_storm_sessions_sup,
            start => {storm_phase_advanced_v1_to_storm_sessions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: big_picture_storm_shelved_v1 -> storm_sessions table
        #{
            id => big_picture_storm_shelved_v1_to_storm_sessions_sup,
            start => {big_picture_storm_shelved_v1_to_storm_sessions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: big_picture_storm_resumed_v1 -> storm_sessions table
        #{
            id => big_picture_storm_resumed_v1_to_storm_sessions_sup,
            start => {big_picture_storm_resumed_v1_to_storm_sessions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: big_picture_storm_archived_v1 -> storm_sessions table
        #{
            id => big_picture_storm_archived_v1_to_storm_sessions_sup,
            start => {big_picture_storm_archived_v1_to_storm_sessions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },

        %% Projection: event_sticky_posted_v1 -> event_stickies table
        #{
            id => event_sticky_posted_v1_to_event_stickies_sup,
            start => {event_sticky_posted_v1_to_event_stickies_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_sticky_pulled_v1 -> event_stickies table
        #{
            id => event_sticky_pulled_v1_to_event_stickies_sup,
            start => {event_sticky_pulled_v1_to_event_stickies_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_sticky_stacked_v1 -> event_stickies table
        #{
            id => event_sticky_stacked_v1_to_event_stickies_sup,
            start => {event_sticky_stacked_v1_to_event_stickies_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_sticky_unstacked_v1 -> event_stickies table
        #{
            id => event_sticky_unstacked_v1_to_event_stickies_sup,
            start => {event_sticky_unstacked_v1_to_event_stickies_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_stack_groomed_v1 -> event_stickies table
        #{
            id => event_stack_groomed_v1_to_event_stickies_sup,
            start => {event_stack_groomed_v1_to_event_stickies_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_sticky_clustered_v1 -> event_stickies table
        #{
            id => event_sticky_clustered_v1_to_event_stickies_sup,
            start => {event_sticky_clustered_v1_to_event_stickies_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_sticky_unclustered_v1 -> event_stickies table
        #{
            id => event_sticky_unclustered_v1_to_event_stickies_sup,
            start => {event_sticky_unclustered_v1_to_event_stickies_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },

        %% Projection: event_cluster_emerged_v1 -> event_clusters table
        #{
            id => event_cluster_emerged_v1_to_event_clusters_sup,
            start => {event_cluster_emerged_v1_to_event_clusters_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_cluster_named_v1 -> event_clusters table
        #{
            id => event_cluster_named_v1_to_event_clusters_sup,
            start => {event_cluster_named_v1_to_event_clusters_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_cluster_dissolved_v1 -> event_clusters table
        #{
            id => event_cluster_dissolved_v1_to_event_clusters_sup,
            start => {event_cluster_dissolved_v1_to_event_clusters_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_cluster_promoted_v1 -> event_clusters table
        #{
            id => event_cluster_promoted_v1_to_event_clusters_sup,
            start => {event_cluster_promoted_v1_to_event_clusters_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },

        %% Projection: fact_arrow_drawn_v1 -> fact_arrows table
        #{
            id => fact_arrow_drawn_v1_to_fact_arrows_sup,
            start => {fact_arrow_drawn_v1_to_fact_arrows_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: fact_arrow_erased_v1 -> fact_arrows table
        #{
            id => fact_arrow_erased_v1_to_fact_arrows_sup,
            start => {fact_arrow_erased_v1_to_fact_arrows_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
