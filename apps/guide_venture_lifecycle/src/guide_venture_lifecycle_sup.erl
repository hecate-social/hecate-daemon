%%% @doc guide_venture_lifecycle top-level supervisor
%%%
%%% Supervises all emitters for venture lifecycle events:
%%% - PG emitters: subscribe to evoq, broadcast to pg groups (internal)
%%% - Mesh emitters: subscribe to evoq, publish to mesh (external)
%%% - TUI emitters: subscribe to evoq, broadcast to TUI connections (local)
%%% @end
-module(guide_venture_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% ── PG emitters (internal, subscribe via evoq → broadcast to pg) ────

        %% Venture lifecycle
        #{id => venture_initiated_v1_to_pg,
          start => {venture_initiated_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => vision_refined_v1_to_pg,
          start => {vision_refined_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => vision_submitted_v1_to_pg,
          start => {vision_submitted_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => venture_archived_v1_to_pg,
          start => {venture_archived_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% Scaffold
        #{id => venture_repo_scaffolded_v1_to_pg,
          start => {venture_repo_scaffolded_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% Discovery
        #{id => discovery_started_v1_to_pg,
          start => {discovery_started_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => discovery_paused_v1_to_pg,
          start => {discovery_paused_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => discovery_resumed_v1_to_pg,
          start => {discovery_resumed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => discovery_completed_v1_to_pg,
          start => {discovery_completed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => division_identified_v1_to_pg,
          start => {division_identified_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% Big Picture Storm lifecycle
        #{id => big_picture_storm_started_v1_to_pg,
          start => {big_picture_storm_started_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => big_picture_storm_shelved_v1_to_pg,
          start => {big_picture_storm_shelved_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => big_picture_storm_resumed_v1_to_pg,
          start => {big_picture_storm_resumed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => big_picture_storm_archived_v1_to_pg,
          start => {big_picture_storm_archived_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => storm_phase_advanced_v1_to_pg,
          start => {storm_phase_advanced_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% Stickies
        #{id => event_sticky_posted_v1_to_pg,
          start => {event_sticky_posted_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_pulled_v1_to_pg,
          start => {event_sticky_pulled_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_stacked_v1_to_pg,
          start => {event_sticky_stacked_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_unstacked_v1_to_pg,
          start => {event_sticky_unstacked_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_clustered_v1_to_pg,
          start => {event_sticky_clustered_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_unclustered_v1_to_pg,
          start => {event_sticky_unclustered_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% Stacks
        #{id => event_stack_emerged_v1_to_pg,
          start => {event_stack_emerged_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_stack_groomed_v1_to_pg,
          start => {event_stack_groomed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% Clusters
        #{id => event_cluster_emerged_v1_to_pg,
          start => {event_cluster_emerged_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_cluster_named_v1_to_pg,
          start => {event_cluster_named_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_cluster_dissolved_v1_to_pg,
          start => {event_cluster_dissolved_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_cluster_promoted_v1_to_pg,
          start => {event_cluster_promoted_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% Fact arrows
        #{id => fact_arrow_drawn_v1_to_pg,
          start => {fact_arrow_drawn_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => fact_arrow_erased_v1_to_pg,
          start => {fact_arrow_erased_v1_to_pg, start_link, []},
          restart => permanent, type => worker},

        %% ── Mesh emitters (external, subscribe via evoq → publish to mesh) ──

        %% Venture lifecycle
        #{id => venture_initiated_v1_to_mesh,
          start => {venture_initiated_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => discovery_started_v1_to_mesh,
          start => {discovery_started_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => division_identified_v1_to_mesh,
          start => {division_identified_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},

        %% Big Picture Storm mesh emitters
        #{id => big_picture_storm_started_v1_to_mesh,
          start => {big_picture_storm_started_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => big_picture_storm_shelved_v1_to_mesh,
          start => {big_picture_storm_shelved_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => big_picture_storm_resumed_v1_to_mesh,
          start => {big_picture_storm_resumed_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => big_picture_storm_archived_v1_to_mesh,
          start => {big_picture_storm_archived_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_posted_v1_to_mesh,
          start => {event_sticky_posted_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_pulled_v1_to_mesh,
          start => {event_sticky_pulled_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_stack_emerged_v1_to_mesh,
          start => {event_stack_emerged_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_stacked_v1_to_mesh,
          start => {event_sticky_stacked_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_unstacked_v1_to_mesh,
          start => {event_sticky_unstacked_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_stack_groomed_v1_to_mesh,
          start => {event_stack_groomed_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => storm_phase_advanced_v1_to_mesh,
          start => {storm_phase_advanced_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_cluster_emerged_v1_to_mesh,
          start => {event_cluster_emerged_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_clustered_v1_to_mesh,
          start => {event_sticky_clustered_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_sticky_unclustered_v1_to_mesh,
          start => {event_sticky_unclustered_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_cluster_dissolved_v1_to_mesh,
          start => {event_cluster_dissolved_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_cluster_named_v1_to_mesh,
          start => {event_cluster_named_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => fact_arrow_drawn_v1_to_mesh,
          start => {fact_arrow_drawn_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => fact_arrow_erased_v1_to_mesh,
          start => {fact_arrow_erased_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},
        #{id => event_cluster_promoted_v1_to_mesh,
          start => {event_cluster_promoted_v1_to_mesh, start_link, []},
          restart => permanent, type => worker},

        %% ── TUI emitters (local, subscribe via evoq → broadcast to TUI) ────

        #{id => venture_initiated_v1_to_tui,
          start => {venture_initiated_v1_to_tui, start_link, []},
          restart => permanent, type => worker},
        #{id => discovery_started_v1_to_tui,
          start => {discovery_started_v1_to_tui, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
