-module(guide_venture_lifecycle_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        %% Inception
        {"/api/ventures/initiate", initiate_venture_api, []},
        {"/api/ventures/:venture_id/vision/refine", refine_vision_api, []},
        {"/api/ventures/:venture_id/vision/submit", submit_vision_api, []},
        %% Discovery
        {"/api/ventures/:venture_id/discovery/start", start_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/identify", identify_division_api, []},
        {"/api/ventures/:venture_id/discovery/pause", pause_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/resume", resume_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/complete", complete_discovery_api, []},
        %% Archive
        {"/api/ventures/:venture_id/archive", archive_venture_api, []},
        %% Big Picture Event Storming — lifecycle
        {"/api/ventures/:venture_id/storm/start", start_big_picture_storm_api, []},
        {"/api/ventures/:venture_id/storm/shelve", shelve_big_picture_storm_api, []},
        {"/api/ventures/:venture_id/storm/resume", resume_big_picture_storm_api, []},
        {"/api/ventures/:venture_id/storm/archive", archive_big_picture_storm_api, []},
        %% Big Picture Event Storming — stickies
        {"/api/ventures/:venture_id/storm/sticky", post_event_sticky_api, []},
        {"/api/ventures/:venture_id/storm/sticky/:sticky_id/pull", pull_event_sticky_api, []},
        {"/api/ventures/:venture_id/storm/sticky/:sticky_id/stack", stack_event_sticky_api, []},
        {"/api/ventures/:venture_id/storm/sticky/:sticky_id/unstack", unstack_event_sticky_api, []},
        {"/api/ventures/:venture_id/storm/sticky/:sticky_id/cluster", cluster_event_sticky_api, []},
        {"/api/ventures/:venture_id/storm/sticky/:sticky_id/uncluster", uncluster_event_sticky_api, []},
        %% Big Picture Event Storming — stacks
        {"/api/ventures/:venture_id/storm/stack/:stack_id/groom", groom_event_stack_api, []},
        %% Big Picture Event Storming — clusters
        {"/api/ventures/:venture_id/storm/cluster/:cluster_id/dissolve", dissolve_event_cluster_api, []},
        {"/api/ventures/:venture_id/storm/cluster/:cluster_id/name", name_event_cluster_api, []},
        {"/api/ventures/:venture_id/storm/cluster/:cluster_id/promote", promote_event_cluster_api, []},
        %% Big Picture Event Storming — fact arrows
        {"/api/ventures/:venture_id/storm/fact", draw_fact_arrow_api, []},
        {"/api/ventures/:venture_id/storm/fact/:arrow_id/erase", erase_fact_arrow_api, []},
        %% Big Picture Event Storming — phase
        {"/api/ventures/:venture_id/storm/phase/advance", advance_storm_phase_api, []}
    ].
