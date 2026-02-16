%%% @doc Tests for Big Picture Event Storming aggregate logic.
%%%
%%% Pure logic tests — no external deps (no ReckonDB, no mesh).
%%% Tests all 17 storm command types through the venture aggregate,
%%% state guards, bit flag transitions, and the full storm lifecycle.
-module(storm_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_venture_lifecycle/include/venture_lifecycle_status.hrl").
-include_lib("guide_venture_lifecycle/include/venture_state.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

storm_test_() ->
    [
        %% Storm lifecycle
        {"start storm succeeds during discovery",       fun exec_start_storm_ok/0},
        {"start storm blocked when not discovering",    fun exec_start_storm_not_discovering/0},
        {"start storm blocked when already storming",   fun exec_start_storm_already_active/0},
        {"shelve storm succeeds",                       fun exec_shelve_storm_ok/0},
        {"shelve storm blocked when not active",        fun exec_shelve_storm_not_active/0},
        {"resume storm succeeds after shelve",          fun exec_resume_storm_ok/0},
        {"resume storm blocked when not shelved",       fun exec_resume_storm_not_shelved/0},
        {"archive storm succeeds when active",          fun exec_archive_storm_active/0},
        {"archive storm succeeds when shelved",         fun exec_archive_storm_shelved/0},
        {"archive storm blocked when no storm",         fun exec_archive_storm_none/0},

        %% Sticky operations
        {"post sticky succeeds during storm",           fun exec_post_sticky_ok/0},
        {"post sticky blocked when not storming",       fun exec_post_sticky_not_storming/0},
        {"pull sticky succeeds",                        fun exec_pull_sticky_ok/0},

        %% Stack operations
        {"stack sticky creates new stack",              fun exec_stack_sticky_new_stack/0},
        {"stack sticky onto existing stack",            fun exec_stack_sticky_existing/0},
        {"unstack sticky succeeds",                     fun exec_unstack_sticky_ok/0},
        {"groom stack succeeds",                        fun exec_groom_stack_ok/0},

        %% Cluster operations
        {"cluster sticky creates new cluster",          fun exec_cluster_sticky_new/0},
        {"cluster sticky onto existing cluster",        fun exec_cluster_sticky_existing/0},
        {"uncluster sticky succeeds",                   fun exec_uncluster_sticky_ok/0},
        {"dissolve cluster succeeds",                   fun exec_dissolve_cluster_ok/0},
        {"name cluster succeeds",                       fun exec_name_cluster_ok/0},

        %% Fact arrows
        {"draw fact arrow succeeds",                    fun exec_draw_arrow_ok/0},
        {"erase fact arrow succeeds",                   fun exec_erase_arrow_ok/0},

        %% Promote
        {"promote cluster emits two events",            fun exec_promote_cluster_ok/0},

        %% Phase advancement
        {"advance phase storm->stack succeeds",         fun exec_advance_phase_ok/0},
        {"advance phase invalid transition blocked",    fun exec_advance_phase_invalid/0},

        %% Apply: state transitions
        {"apply storm_started sets flags and phase",    fun apply_storm_started/0},
        {"apply sticky_posted adds to stickies",        fun apply_sticky_posted/0},
        {"apply sticky_pulled removes sticky",          fun apply_sticky_pulled/0},
        {"apply stack_emerged adds stack",              fun apply_stack_emerged/0},
        {"apply sticky_stacked updates both",           fun apply_sticky_stacked/0},
        {"apply sticky_unstacked clears stack_id",      fun apply_sticky_unstacked/0},
        {"apply stack_groomed sets weight and removes", fun apply_stack_groomed/0},
        {"apply cluster_emerged adds cluster",          fun apply_cluster_emerged/0},
        {"apply sticky_clustered updates both",         fun apply_sticky_clustered/0},
        {"apply sticky_unclustered clears cluster_id",  fun apply_sticky_unclustered/0},
        {"apply cluster_dissolved unclusters stickies", fun apply_cluster_dissolved/0},
        {"apply cluster_named sets name",               fun apply_cluster_named/0},
        {"apply arrow_drawn adds arrow",                fun apply_arrow_drawn/0},
        {"apply arrow_erased removes arrow",            fun apply_arrow_erased/0},
        {"apply cluster_promoted sets status",          fun apply_cluster_promoted/0},
        {"apply phase_advanced changes phase",          fun apply_phase_advanced/0},
        {"apply storm_shelved toggles flags",           fun apply_storm_shelved/0},
        {"apply storm_resumed toggles flags back",      fun apply_storm_resumed/0},
        {"apply storm_archived clears everything",      fun apply_storm_archived/0},

        %% Full lifecycle
        {"full storm lifecycle flow",                   fun full_storm_lifecycle/0}
    ].

%% ===================================================================
%% Helpers
%% ===================================================================

fresh() -> venture_aggregate:initial_state().

apply_events(Events) ->
    lists:foldl(fun(E, S) -> venture_aggregate:apply_event(E, S) end, fresh(), Events).

initiated_event() ->
    #{<<"event_type">> => <<"venture_initiated_v1">>,
      <<"venture_id">> => <<"v-storm-1">>,
      <<"name">> => <<"Storm Test Venture">>,
      <<"initiated_at">> => 1000}.

discovering_events() ->
    [initiated_event(),
     #{<<"event_type">> => <<"vision_submitted_v1">>,
       <<"venture_id">> => <<"v-storm-1">>},
     #{<<"event_type">> => <<"discovery_started_v1">>,
       <<"venture_id">> => <<"v-storm-1">>,
       <<"started_at">> => 2000}].

discovering_state() ->
    apply_events(discovering_events()).

storming_events() ->
    discovering_events() ++ [
        #{<<"event_type">> => <<"big_picture_storm_started_v1">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"storm_number">> => 1,
          <<"started_at">> => 3000}
    ].

storming_state() ->
    apply_events(storming_events()).

%% Storming state with two stickies added
with_stickies_state() ->
    apply_events(storming_events() ++ [
        #{<<"event_type">> => <<"event_sticky_posted_v1">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"sticky_id">> => <<"s-1">>,
          <<"text">> => <<"order_placed">>,
          <<"author">> => <<"user">>,
          <<"created_at">> => 4000},
        #{<<"event_type">> => <<"event_sticky_posted_v1">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"sticky_id">> => <<"s-2">>,
          <<"text">> => <<"order_shipped">>,
          <<"author">> => <<"user">>,
          <<"created_at">> => 4001}
    ]).

%% Storming state with stickies + a stack
with_stack_state() ->
    apply_events(storming_events() ++ [
        #{<<"event_type">> => <<"event_sticky_posted_v1">>,
          <<"sticky_id">> => <<"s-1">>, <<"text">> => <<"order_placed">>,
          <<"author">> => <<"user">>, <<"created_at">> => 4000},
        #{<<"event_type">> => <<"event_sticky_posted_v1">>,
          <<"sticky_id">> => <<"s-2">>, <<"text">> => <<"order_received">>,
          <<"author">> => <<"user">>, <<"created_at">> => 4001},
        #{<<"event_type">> => <<"event_sticky_posted_v1">>,
          <<"sticky_id">> => <<"s-3">>, <<"text">> => <<"order_shipped">>,
          <<"author">> => <<"user">>, <<"created_at">> => 4002},
        #{<<"event_type">> => <<"event_stack_emerged_v1">>,
          <<"stack_id">> => <<"stk-1">>, <<"color">> => <<"#a78bfa">>,
          <<"sticky_ids">> => [<<"s-1">>, <<"s-2">>]},
        #{<<"event_type">> => <<"event_sticky_stacked_v1">>,
          <<"sticky_id">> => <<"s-1">>, <<"stack_id">> => <<"stk-1">>},
        #{<<"event_type">> => <<"event_sticky_stacked_v1">>,
          <<"sticky_id">> => <<"s-2">>, <<"stack_id">> => <<"stk-1">>}
    ]).

%% Storming state with a cluster containing one sticky
with_cluster_state() ->
    apply_events(storming_events() ++ [
        #{<<"event_type">> => <<"event_sticky_posted_v1">>,
          <<"sticky_id">> => <<"s-1">>, <<"text">> => <<"order_placed">>,
          <<"author">> => <<"user">>, <<"created_at">> => 4000},
        #{<<"event_type">> => <<"event_sticky_posted_v1">>,
          <<"sticky_id">> => <<"s-2">>, <<"text">> => <<"order_shipped">>,
          <<"author">> => <<"user">>, <<"created_at">> => 4001},
        #{<<"event_type">> => <<"event_cluster_emerged_v1">>,
          <<"cluster_id">> => <<"cl-1">>, <<"color">> => <<"#60a5fa">>,
          <<"sticky_ids">> => [<<"s-1">>]},
        #{<<"event_type">> => <<"event_sticky_clustered_v1">>,
          <<"sticky_id">> => <<"s-1">>, <<"cluster_id">> => <<"cl-1">>}
    ]).

%% State with a named cluster + fact arrow
with_arrows_state() ->
    apply_events(storming_events() ++ [
        #{<<"event_type">> => <<"event_sticky_posted_v1">>,
          <<"sticky_id">> => <<"s-1">>, <<"text">> => <<"order_placed">>,
          <<"author">> => <<"user">>, <<"created_at">> => 4000},
        #{<<"event_type">> => <<"event_cluster_emerged_v1">>,
          <<"cluster_id">> => <<"cl-1">>, <<"color">> => <<"#60a5fa">>,
          <<"sticky_ids">> => [<<"s-1">>]},
        #{<<"event_type">> => <<"event_sticky_clustered_v1">>,
          <<"sticky_id">> => <<"s-1">>, <<"cluster_id">> => <<"cl-1">>},
        #{<<"event_type">> => <<"event_cluster_named_v1">>,
          <<"cluster_id">> => <<"cl-1">>, <<"name">> => <<"orders">>},
        #{<<"event_type">> => <<"event_sticky_posted_v1">>,
          <<"sticky_id">> => <<"s-2">>, <<"text">> => <<"payment_received">>,
          <<"author">> => <<"user">>, <<"created_at">> => 4001},
        #{<<"event_type">> => <<"event_cluster_emerged_v1">>,
          <<"cluster_id">> => <<"cl-2">>, <<"color">> => <<"#34d399">>,
          <<"sticky_ids">> => [<<"s-2">>]},
        #{<<"event_type">> => <<"event_sticky_clustered_v1">>,
          <<"sticky_id">> => <<"s-2">>, <<"cluster_id">> => <<"cl-2">>},
        #{<<"event_type">> => <<"event_cluster_named_v1">>,
          <<"cluster_id">> => <<"cl-2">>, <<"name">> => <<"payments">>},
        #{<<"event_type">> => <<"fact_arrow_drawn_v1">>,
          <<"arrow_id">> => <<"arr-1">>,
          <<"from_cluster">> => <<"cl-1">>,
          <<"to_cluster">> => <<"cl-2">>,
          <<"fact_name">> => <<"order_confirmed">>}
    ]).

shelved_state() ->
    apply_events(storming_events() ++ [
        #{<<"event_type">> => <<"big_picture_storm_shelved_v1">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"shelved_at">> => 5000}
    ]).

%% ===================================================================
%% Execute: Storm Lifecycle
%% ===================================================================

exec_start_storm_ok() ->
    Cmd = #{<<"command_type">> => <<"start_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>},
    {ok, [Event]} = venture_aggregate:execute(discovering_state(), Cmd),
    ?assertEqual(<<"big_picture_storm_started_v1">>, maps:get(<<"event_type">>, Event)).

exec_start_storm_not_discovering() ->
    State = apply_events([initiated_event()]),
    Cmd = #{<<"command_type">> => <<"start_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>},
    ?assertEqual({error, discovery_not_active},
                 venture_aggregate:execute(State, Cmd)).

exec_start_storm_already_active() ->
    Cmd = #{<<"command_type">> => <<"start_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>},
    ?assertEqual({error, storm_already_active},
                 venture_aggregate:execute(storming_state(), Cmd)).

exec_shelve_storm_ok() ->
    Cmd = #{<<"command_type">> => <<"shelve_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"reason">> => <<"lunch break">>},
    {ok, [Event]} = venture_aggregate:execute(storming_state(), Cmd),
    ?assertEqual(<<"big_picture_storm_shelved_v1">>, maps:get(<<"event_type">>, Event)).

exec_shelve_storm_not_active() ->
    Cmd = #{<<"command_type">> => <<"shelve_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>},
    ?assertEqual({error, storm_not_active},
                 venture_aggregate:execute(discovering_state(), Cmd)).

exec_resume_storm_ok() ->
    Cmd = #{<<"command_type">> => <<"resume_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>},
    {ok, [Event]} = venture_aggregate:execute(shelved_state(), Cmd),
    ?assertEqual(<<"big_picture_storm_resumed_v1">>, maps:get(<<"event_type">>, Event)).

exec_resume_storm_not_shelved() ->
    Cmd = #{<<"command_type">> => <<"resume_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>},
    ?assertEqual({error, storm_not_shelved},
                 venture_aggregate:execute(storming_state(), Cmd)).

exec_archive_storm_active() ->
    Cmd = #{<<"command_type">> => <<"archive_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>},
    {ok, [Event]} = venture_aggregate:execute(storming_state(), Cmd),
    ?assertEqual(<<"big_picture_storm_archived_v1">>, maps:get(<<"event_type">>, Event)).

exec_archive_storm_shelved() ->
    Cmd = #{<<"command_type">> => <<"archive_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>},
    {ok, [Event]} = venture_aggregate:execute(shelved_state(), Cmd),
    ?assertEqual(<<"big_picture_storm_archived_v1">>, maps:get(<<"event_type">>, Event)).

exec_archive_storm_none() ->
    Cmd = #{<<"command_type">> => <<"archive_big_picture_storm">>,
            <<"venture_id">> => <<"v-storm-1">>},
    ?assertEqual({error, no_storm_to_archive},
                 venture_aggregate:execute(discovering_state(), Cmd)).

%% ===================================================================
%% Execute: Sticky Operations
%% ===================================================================

exec_post_sticky_ok() ->
    Cmd = #{<<"command_type">> => <<"post_event_sticky">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"text">> => <<"order_placed">>},
    {ok, [Event]} = venture_aggregate:execute(storming_state(), Cmd),
    ?assertEqual(<<"event_sticky_posted_v1">>, maps:get(<<"event_type">>, Event)),
    ?assertEqual(<<"order_placed">>, maps:get(<<"text">>, Event)).

exec_post_sticky_not_storming() ->
    Cmd = #{<<"command_type">> => <<"post_event_sticky">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"text">> => <<"order_placed">>},
    ?assertEqual({error, storm_not_active},
                 venture_aggregate:execute(discovering_state(), Cmd)).

exec_pull_sticky_ok() ->
    Cmd = #{<<"command_type">> => <<"pull_event_sticky">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"sticky_id">> => <<"s-1">>},
    {ok, [Event]} = venture_aggregate:execute(with_stickies_state(), Cmd),
    ?assertEqual(<<"event_sticky_pulled_v1">>, maps:get(<<"event_type">>, Event)).

%% ===================================================================
%% Execute: Stack Operations
%% ===================================================================

exec_stack_sticky_new_stack() ->
    %% Stack s-1 onto s-2, both free — should create stack + 2 stacked events
    Cmd = #{<<"command_type">> => <<"stack_event_sticky">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"sticky_id">> => <<"s-1">>,
            <<"target_sticky_id">> => <<"s-2">>},
    {ok, Events} = venture_aggregate:execute(with_stickies_state(), Cmd),
    %% Multi-event: emerged + stacked + stacked
    EventTypes = [maps:get(<<"event_type">>, E) || E <- Events],
    ?assert(lists:member(<<"event_stack_emerged_v1">>, EventTypes)),
    ?assert(lists:member(<<"event_sticky_stacked_v1">>, EventTypes)).

exec_stack_sticky_existing() ->
    %% s-3 is free, s-1 is already in stk-1 — should only emit stacked
    Cmd = #{<<"command_type">> => <<"stack_event_sticky">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"sticky_id">> => <<"s-3">>,
            <<"target_sticky_id">> => <<"s-1">>},
    {ok, Events} = venture_aggregate:execute(with_stack_state(), Cmd),
    EventTypes = [maps:get(<<"event_type">>, E) || E <- Events],
    %% No new stack emerged — just stacked
    ?assertNot(lists:member(<<"event_stack_emerged_v1">>, EventTypes)),
    ?assert(lists:member(<<"event_sticky_stacked_v1">>, EventTypes)).

exec_unstack_sticky_ok() ->
    Cmd = #{<<"command_type">> => <<"unstack_event_sticky">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"sticky_id">> => <<"s-1">>},
    {ok, [Event]} = venture_aggregate:execute(with_stack_state(), Cmd),
    ?assertEqual(<<"event_sticky_unstacked_v1">>, maps:get(<<"event_type">>, Event)),
    ?assertEqual(<<"stk-1">>, maps:get(<<"stack_id">>, Event)).

exec_groom_stack_ok() ->
    Cmd = #{<<"command_type">> => <<"groom_event_stack">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"stack_id">> => <<"stk-1">>,
            <<"canonical_sticky_id">> => <<"s-1">>},
    {ok, [Event]} = venture_aggregate:execute(with_stack_state(), Cmd),
    ?assertEqual(<<"event_stack_groomed_v1">>, maps:get(<<"event_type">>, Event)),
    ?assertEqual(<<"s-1">>, maps:get(<<"canonical_sticky_id">>, Event)),
    Weight = maps:get(<<"weight">>, Event),
    ?assert(Weight >= 2).

%% ===================================================================
%% Execute: Cluster Operations
%% ===================================================================

exec_cluster_sticky_new() ->
    %% Cluster s-1 onto s-2 — both free, should emerge new cluster
    %% target_cluster_id = s-2 (a sticky ID, not a cluster ID) triggers new cluster emergence
    Cmd = #{<<"command_type">> => <<"cluster_event_sticky">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"sticky_id">> => <<"s-1">>,
            <<"target_cluster_id">> => <<"s-2">>},
    {ok, Events} = venture_aggregate:execute(with_stickies_state(), Cmd),
    EventTypes = [maps:get(<<"event_type">>, E) || E <- Events],
    ?assert(lists:member(<<"event_cluster_emerged_v1">>, EventTypes)),
    ?assert(lists:member(<<"event_sticky_clustered_v1">>, EventTypes)).

exec_cluster_sticky_existing() ->
    %% s-2 is free, cl-1 exists with s-1 — cluster s-2 into existing cl-1
    Cmd = #{<<"command_type">> => <<"cluster_event_sticky">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"sticky_id">> => <<"s-2">>,
            <<"target_cluster_id">> => <<"cl-1">>},
    {ok, Events} = venture_aggregate:execute(with_cluster_state(), Cmd),
    EventTypes = [maps:get(<<"event_type">>, E) || E <- Events],
    ?assertNot(lists:member(<<"event_cluster_emerged_v1">>, EventTypes)),
    ?assert(lists:member(<<"event_sticky_clustered_v1">>, EventTypes)).

exec_uncluster_sticky_ok() ->
    Cmd = #{<<"command_type">> => <<"uncluster_event_sticky">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"sticky_id">> => <<"s-1">>},
    {ok, [Event]} = venture_aggregate:execute(with_cluster_state(), Cmd),
    ?assertEqual(<<"event_sticky_unclustered_v1">>, maps:get(<<"event_type">>, Event)).

exec_dissolve_cluster_ok() ->
    Cmd = #{<<"command_type">> => <<"dissolve_event_cluster">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"cluster_id">> => <<"cl-1">>},
    {ok, [Event]} = venture_aggregate:execute(with_cluster_state(), Cmd),
    ?assertEqual(<<"event_cluster_dissolved_v1">>, maps:get(<<"event_type">>, Event)).

exec_name_cluster_ok() ->
    Cmd = #{<<"command_type">> => <<"name_event_cluster">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"cluster_id">> => <<"cl-1">>,
            <<"name">> => <<"orders">>},
    {ok, [Event]} = venture_aggregate:execute(with_cluster_state(), Cmd),
    ?assertEqual(<<"event_cluster_named_v1">>, maps:get(<<"event_type">>, Event)),
    ?assertEqual(<<"orders">>, maps:get(<<"name">>, Event)).

%% ===================================================================
%% Execute: Fact Arrows
%% ===================================================================

exec_draw_arrow_ok() ->
    Cmd = #{<<"command_type">> => <<"draw_fact_arrow">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"from_cluster">> => <<"cl-1">>,
            <<"to_cluster">> => <<"cl-2">>,
            <<"fact_name">> => <<"order_confirmed">>},
    {ok, [Event]} = venture_aggregate:execute(with_arrows_state(), Cmd),
    ?assertEqual(<<"fact_arrow_drawn_v1">>, maps:get(<<"event_type">>, Event)),
    ?assertEqual(<<"order_confirmed">>, maps:get(<<"fact_name">>, Event)).

exec_erase_arrow_ok() ->
    Cmd = #{<<"command_type">> => <<"erase_fact_arrow">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"arrow_id">> => <<"arr-1">>},
    {ok, [Event]} = venture_aggregate:execute(with_arrows_state(), Cmd),
    ?assertEqual(<<"fact_arrow_erased_v1">>, maps:get(<<"event_type">>, Event)).

%% ===================================================================
%% Execute: Promote
%% ===================================================================

exec_promote_cluster_ok() ->
    Cmd = #{<<"command_type">> => <<"promote_event_cluster">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"cluster_id">> => <<"cl-1">>},
    {ok, Events} = venture_aggregate:execute(with_arrows_state(), Cmd),
    EventTypes = [maps:get(<<"event_type">>, E) || E <- Events],
    ?assert(lists:member(<<"event_cluster_promoted_v1">>, EventTypes)),
    ?assert(lists:member(<<"division_identified_v1">>, EventTypes)).

%% ===================================================================
%% Execute: Phase Advancement
%% ===================================================================

exec_advance_phase_ok() ->
    Cmd = #{<<"command_type">> => <<"advance_storm_phase">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"target_phase">> => <<"stack">>},
    {ok, [Event]} = venture_aggregate:execute(storming_state(), Cmd),
    ?assertEqual(<<"storm_phase_advanced_v1">>, maps:get(<<"event_type">>, Event)),
    ?assertEqual(<<"stack">>, maps:get(<<"phase">>, Event)).

exec_advance_phase_invalid() ->
    %% Current phase is storm, trying to jump to name (skipping stack, groom, cluster)
    Cmd = #{<<"command_type">> => <<"advance_storm_phase">>,
            <<"venture_id">> => <<"v-storm-1">>,
            <<"target_phase">> => <<"name">>},
    ?assertEqual({error, invalid_phase_transition},
                 venture_aggregate:execute(storming_state(), Cmd)).

%% ===================================================================
%% Apply: Storm State Transitions
%% ===================================================================

apply_storm_started() ->
    State = storming_state(),
    ?assert(State#venture_state.status band ?VL_STORMING =/= 0),
    ?assertEqual(storm, State#venture_state.storm_phase),
    ?assertEqual(1, State#venture_state.storm_number),
    ?assertEqual(3000, State#venture_state.storm_started_at),
    ?assertEqual(#{}, State#venture_state.event_stickies).

apply_sticky_posted() ->
    Event = #{<<"event_type">> => <<"event_sticky_posted_v1">>,
              <<"sticky_id">> => <<"s-99">>,
              <<"text">> => <<"payment_received">>,
              <<"author">> => <<"oracle">>,
              <<"created_at">> => 5000},
    State = venture_aggregate:apply_event(Event, storming_state()),
    ?assert(maps:is_key(<<"s-99">>, State#venture_state.event_stickies)),
    Sticky = maps:get(<<"s-99">>, State#venture_state.event_stickies),
    ?assertEqual(<<"payment_received">>, maps:get(text, Sticky)),
    ?assertEqual(<<"oracle">>, maps:get(author, Sticky)),
    ?assertEqual(1, maps:get(weight, Sticky)),
    ?assertEqual(undefined, maps:get(stack_id, Sticky)),
    ?assertEqual(undefined, maps:get(cluster_id, Sticky)).

apply_sticky_pulled() ->
    State0 = with_stickies_state(),
    ?assert(maps:is_key(<<"s-1">>, State0#venture_state.event_stickies)),
    Event = #{<<"event_type">> => <<"event_sticky_pulled_v1">>,
              <<"sticky_id">> => <<"s-1">>},
    State1 = venture_aggregate:apply_event(Event, State0),
    ?assertNot(maps:is_key(<<"s-1">>, State1#venture_state.event_stickies)),
    ?assert(maps:is_key(<<"s-2">>, State1#venture_state.event_stickies)).

apply_stack_emerged() ->
    Event = #{<<"event_type">> => <<"event_stack_emerged_v1">>,
              <<"stack_id">> => <<"stk-99">>,
              <<"color">> => <<"#ff0000">>,
              <<"sticky_ids">> => [<<"s-1">>, <<"s-2">>]},
    State = venture_aggregate:apply_event(Event, storming_state()),
    ?assert(maps:is_key(<<"stk-99">>, State#venture_state.event_stacks)),
    Stack = maps:get(<<"stk-99">>, State#venture_state.event_stacks),
    ?assertEqual(<<"#ff0000">>, maps:get(color, Stack)),
    %% sticky_ids starts empty — stacked events populate it
    ?assertEqual([], maps:get(sticky_ids, Stack)).

apply_sticky_stacked() ->
    State0 = with_stack_state(),
    %% Verify s-1 is in stk-1
    S1 = maps:get(<<"s-1">>, State0#venture_state.event_stickies),
    ?assertEqual(<<"stk-1">>, maps:get(stack_id, S1)),
    %% Verify stack has both stickies
    Stk = maps:get(<<"stk-1">>, State0#venture_state.event_stacks),
    ?assert(lists:member(<<"s-1">>, maps:get(sticky_ids, Stk))),
    ?assert(lists:member(<<"s-2">>, maps:get(sticky_ids, Stk))).

apply_sticky_unstacked() ->
    State0 = with_stack_state(),
    Event = #{<<"event_type">> => <<"event_sticky_unstacked_v1">>,
              <<"sticky_id">> => <<"s-1">>,
              <<"stack_id">> => <<"stk-1">>},
    State1 = venture_aggregate:apply_event(Event, State0),
    S1 = maps:get(<<"s-1">>, State1#venture_state.event_stickies),
    ?assertEqual(undefined, maps:get(stack_id, S1)),
    %% Stack still exists but without s-1
    Stk = maps:get(<<"stk-1">>, State1#venture_state.event_stacks),
    ?assertNot(lists:member(<<"s-1">>, maps:get(sticky_ids, Stk))).

apply_stack_groomed() ->
    State0 = with_stack_state(),
    Event = #{<<"event_type">> => <<"event_stack_groomed_v1">>,
              <<"stack_id">> => <<"stk-1">>,
              <<"canonical_sticky_id">> => <<"s-1">>,
              <<"weight">> => 2,
              <<"absorbed_sticky_ids">> => [<<"s-2">>]},
    State1 = venture_aggregate:apply_event(Event, State0),
    %% Canonical keeps with updated weight, stack_id cleared
    S1 = maps:get(<<"s-1">>, State1#venture_state.event_stickies),
    ?assertEqual(2, maps:get(weight, S1)),
    ?assertEqual(undefined, maps:get(stack_id, S1)),
    %% Absorbed sticky removed
    ?assertNot(maps:is_key(<<"s-2">>, State1#venture_state.event_stickies)),
    %% Stack removed
    ?assertNot(maps:is_key(<<"stk-1">>, State1#venture_state.event_stacks)).

apply_cluster_emerged() ->
    Event = #{<<"event_type">> => <<"event_cluster_emerged_v1">>,
              <<"cluster_id">> => <<"cl-99">>,
              <<"color">> => <<"#34d399">>,
              <<"sticky_ids">> => [<<"s-1">>]},
    State = venture_aggregate:apply_event(Event, storming_state()),
    ?assert(maps:is_key(<<"cl-99">>, State#venture_state.event_clusters)),
    Cl = maps:get(<<"cl-99">>, State#venture_state.event_clusters),
    ?assertEqual(undefined, maps:get(name, Cl)),
    ?assertEqual(<<"#34d399">>, maps:get(color, Cl)),
    ?assertEqual(active, maps:get(status, Cl)).

apply_sticky_clustered() ->
    State0 = with_cluster_state(),
    S1 = maps:get(<<"s-1">>, State0#venture_state.event_stickies),
    ?assertEqual(<<"cl-1">>, maps:get(cluster_id, S1)),
    Cl = maps:get(<<"cl-1">>, State0#venture_state.event_clusters),
    ?assert(lists:member(<<"s-1">>, maps:get(sticky_ids, Cl))).

apply_sticky_unclustered() ->
    State0 = with_cluster_state(),
    Event = #{<<"event_type">> => <<"event_sticky_unclustered_v1">>,
              <<"sticky_id">> => <<"s-1">>,
              <<"cluster_id">> => <<"cl-1">>},
    State1 = venture_aggregate:apply_event(Event, State0),
    S1 = maps:get(<<"s-1">>, State1#venture_state.event_stickies),
    ?assertEqual(undefined, maps:get(cluster_id, S1)),
    Cl = maps:get(<<"cl-1">>, State1#venture_state.event_clusters),
    ?assertNot(lists:member(<<"s-1">>, maps:get(sticky_ids, Cl))).

apply_cluster_dissolved() ->
    State0 = with_cluster_state(),
    Event = #{<<"event_type">> => <<"event_cluster_dissolved_v1">>,
              <<"cluster_id">> => <<"cl-1">>},
    State1 = venture_aggregate:apply_event(Event, State0),
    %% Cluster status = dissolved, stickies cleared
    Cl = maps:get(<<"cl-1">>, State1#venture_state.event_clusters),
    ?assertEqual(dissolved, maps:get(status, Cl)),
    ?assertEqual([], maps:get(sticky_ids, Cl)),
    %% Sticky s-1 unclustered
    S1 = maps:get(<<"s-1">>, State1#venture_state.event_stickies),
    ?assertEqual(undefined, maps:get(cluster_id, S1)).

apply_cluster_named() ->
    Event = #{<<"event_type">> => <<"event_cluster_named_v1">>,
              <<"cluster_id">> => <<"cl-1">>,
              <<"name">> => <<"orders">>},
    State = venture_aggregate:apply_event(Event, with_cluster_state()),
    Cl = maps:get(<<"cl-1">>, State#venture_state.event_clusters),
    ?assertEqual(<<"orders">>, maps:get(name, Cl)).

apply_arrow_drawn() ->
    Event = #{<<"event_type">> => <<"fact_arrow_drawn_v1">>,
              <<"arrow_id">> => <<"arr-99">>,
              <<"from_cluster">> => <<"cl-1">>,
              <<"to_cluster">> => <<"cl-2">>,
              <<"fact_name">> => <<"order_paid">>},
    State = venture_aggregate:apply_event(Event, storming_state()),
    ?assert(maps:is_key(<<"arr-99">>, State#venture_state.fact_arrows)),
    Arrow = maps:get(<<"arr-99">>, State#venture_state.fact_arrows),
    ?assertEqual(<<"cl-1">>, maps:get(from_cluster, Arrow)),
    ?assertEqual(<<"cl-2">>, maps:get(to_cluster, Arrow)),
    ?assertEqual(<<"order_paid">>, maps:get(fact_name, Arrow)).

apply_arrow_erased() ->
    State0 = with_arrows_state(),
    ?assert(maps:is_key(<<"arr-1">>, State0#venture_state.fact_arrows)),
    Event = #{<<"event_type">> => <<"fact_arrow_erased_v1">>,
              <<"arrow_id">> => <<"arr-1">>},
    State1 = venture_aggregate:apply_event(Event, State0),
    ?assertNot(maps:is_key(<<"arr-1">>, State1#venture_state.fact_arrows)).

apply_cluster_promoted() ->
    Event = #{<<"event_type">> => <<"event_cluster_promoted_v1">>,
              <<"cluster_id">> => <<"cl-1">>},
    State = venture_aggregate:apply_event(Event, with_cluster_state()),
    Cl = maps:get(<<"cl-1">>, State#venture_state.event_clusters),
    ?assertEqual(promoted, maps:get(status, Cl)).

apply_phase_advanced() ->
    Event = #{<<"event_type">> => <<"storm_phase_advanced_v1">>,
              <<"phase">> => <<"cluster">>},
    State = venture_aggregate:apply_event(Event, storming_state()),
    ?assertEqual(cluster, State#venture_state.storm_phase).

apply_storm_shelved() ->
    State = shelved_state(),
    ?assert(State#venture_state.status band ?VL_STORM_SHELVED =/= 0),
    ?assert(State#venture_state.status band ?VL_STORMING =:= 0),
    ?assertEqual(shelved, State#venture_state.storm_phase),
    ?assertEqual(5000, State#venture_state.storm_shelved_at).

apply_storm_resumed() ->
    Event = #{<<"event_type">> => <<"big_picture_storm_resumed_v1">>,
              <<"venture_id">> => <<"v-storm-1">>},
    State = venture_aggregate:apply_event(Event, shelved_state()),
    ?assert(State#venture_state.status band ?VL_STORMING =/= 0),
    ?assert(State#venture_state.status band ?VL_STORM_SHELVED =:= 0),
    ?assertEqual(storm, State#venture_state.storm_phase),
    ?assertEqual(undefined, State#venture_state.storm_shelved_at).

apply_storm_archived() ->
    Event = #{<<"event_type">> => <<"big_picture_storm_archived_v1">>,
              <<"venture_id">> => <<"v-storm-1">>},
    State = venture_aggregate:apply_event(Event, storming_state()),
    ?assert(State#venture_state.status band ?VL_STORMING =:= 0),
    ?assert(State#venture_state.status band ?VL_STORM_SHELVED =:= 0),
    ?assertEqual(undefined, State#venture_state.storm_phase),
    ?assertEqual(undefined, State#venture_state.storm_started_at),
    ?assertEqual(#{}, State#venture_state.event_stickies),
    ?assertEqual(#{}, State#venture_state.event_stacks),
    ?assertEqual(#{}, State#venture_state.event_clusters),
    ?assertEqual(#{}, State#venture_state.fact_arrows).

%% ===================================================================
%% Full storm lifecycle integration
%% ===================================================================

full_storm_lifecycle() ->
    S0 = discovering_state(),

    %% 1. Start storm
    {ok, [E1]} = venture_aggregate:execute(S0,
        #{<<"command_type">> => <<"start_big_picture_storm">>,
          <<"venture_id">> => <<"v-storm-1">>}),
    S1 = venture_aggregate:apply_event(E1, S0),
    ?assert(S1#venture_state.status band ?VL_STORMING =/= 0),
    ?assertEqual(storm, S1#venture_state.storm_phase),

    %% 2. Post stickies
    {ok, [E2]} = venture_aggregate:execute(S1,
        #{<<"command_type">> => <<"post_event_sticky">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"text">> => <<"order_placed">>}),
    S2 = venture_aggregate:apply_event(E2, S1),
    StickyId1 = maps:get(<<"sticky_id">>, E2),

    {ok, [E3]} = venture_aggregate:execute(S2,
        #{<<"command_type">> => <<"post_event_sticky">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"text">> => <<"order_received">>}),
    S3 = venture_aggregate:apply_event(E3, S2),
    StickyId2 = maps:get(<<"sticky_id">>, E3),

    ?assertEqual(2, maps:size(S3#venture_state.event_stickies)),

    %% 3. Advance to stack phase
    {ok, [E4]} = venture_aggregate:execute(S3,
        #{<<"command_type">> => <<"advance_storm_phase">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"target_phase">> => <<"stack">>}),
    S4 = venture_aggregate:apply_event(E4, S3),
    ?assertEqual(stack, S4#venture_state.storm_phase),

    %% 4. Stack stickies together
    {ok, StackEvents} = venture_aggregate:execute(S4,
        #{<<"command_type">> => <<"stack_event_sticky">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"sticky_id">> => StickyId1,
          <<"target_sticky_id">> => StickyId2}),
    S5 = lists:foldl(fun(E, Acc) -> venture_aggregate:apply_event(E, Acc) end, S4, StackEvents),
    ?assertEqual(1, maps:size(S5#venture_state.event_stacks)),

    %% 5. Advance to groom phase
    {ok, [E6]} = venture_aggregate:execute(S5,
        #{<<"command_type">> => <<"advance_storm_phase">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"target_phase">> => <<"groom">>}),
    S6 = venture_aggregate:apply_event(E6, S5),

    %% 6. Groom the stack
    [StackId] = maps:keys(S6#venture_state.event_stacks),
    {ok, [E7]} = venture_aggregate:execute(S6,
        #{<<"command_type">> => <<"groom_event_stack">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"stack_id">> => StackId,
          <<"canonical_sticky_id">> => StickyId1}),
    S7 = venture_aggregate:apply_event(E7, S6),
    %% Stack gone, canonical has weight 2, absorbed gone
    ?assertEqual(0, maps:size(S7#venture_state.event_stacks)),
    ?assertEqual(1, maps:size(S7#venture_state.event_stickies)),
    Canonical = maps:get(StickyId1, S7#venture_state.event_stickies),
    ?assertEqual(2, maps:get(weight, Canonical)),

    %% 7. Advance through remaining phases
    {ok, [E8]} = venture_aggregate:execute(S7,
        #{<<"command_type">> => <<"advance_storm_phase">>,
          <<"venture_id">> => <<"v-storm-1">>,
          <<"target_phase">> => <<"cluster">>}),
    S8 = venture_aggregate:apply_event(E8, S7),
    ?assertEqual(cluster, S8#venture_state.storm_phase),

    %% 8. Shelve, resume, then archive
    {ok, [E9]} = venture_aggregate:execute(S8,
        #{<<"command_type">> => <<"shelve_big_picture_storm">>,
          <<"venture_id">> => <<"v-storm-1">>}),
    S9 = venture_aggregate:apply_event(E9, S8),
    ?assert(S9#venture_state.status band ?VL_STORM_SHELVED =/= 0),

    {ok, [E10]} = venture_aggregate:execute(S9,
        #{<<"command_type">> => <<"resume_big_picture_storm">>,
          <<"venture_id">> => <<"v-storm-1">>}),
    S10 = venture_aggregate:apply_event(E10, S9),
    ?assert(S10#venture_state.status band ?VL_STORMING =/= 0),

    {ok, [E11]} = venture_aggregate:execute(S10,
        #{<<"command_type">> => <<"archive_big_picture_storm">>,
          <<"venture_id">> => <<"v-storm-1">>}),
    S11 = venture_aggregate:apply_event(E11, S10),
    ?assert(S11#venture_state.status band ?VL_STORMING =:= 0),
    ?assertEqual(#{}, S11#venture_state.event_stickies),
    ?assertEqual(#{}, S11#venture_state.event_stacks),
    ok.
