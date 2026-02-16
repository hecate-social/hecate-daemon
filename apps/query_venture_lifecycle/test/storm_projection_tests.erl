%%% @doc Tests for Big Picture Event Storming projections (event -> SQLite writes).
%%%
%%% Covers four tables: event_stickies, event_clusters, fact_arrows, storm_sessions
%%% and their corresponding projection modules.
%%%
%%% Uses a temp SQLite database via query_venture_lifecycle_store.
%%% Each test group gets a fresh database (foreach pattern).
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
%%%   Single-column: [[val], ...]
-module(storm_projection_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

sticky_projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"sticky posted projects into event_stickies",           fun proj_sticky_posted/0},
            {"sticky posted with defaults",                          fun proj_sticky_posted_defaults/0},
            {"sticky pulled deletes from event_stickies",            fun proj_sticky_pulled/0},
            {"sticky pulled on nonexistent is harmless",             fun proj_sticky_pulled_noop/0},
            {"sticky stacked sets stack_id",                         fun proj_sticky_stacked/0},
            {"sticky unstacked clears stack_id",                     fun proj_sticky_unstacked/0},
            {"stack groomed updates weight and deletes absorbed",    fun proj_stack_groomed/0},
            {"stack groomed with empty absorbed list",               fun proj_stack_groomed_empty_absorbed/0},
            {"sticky clustered sets cluster_id",                     fun proj_sticky_clustered/0},
            {"sticky unclustered clears cluster_id",                 fun proj_sticky_unclustered/0},
            {"sticky lifecycle: post -> stack -> cluster -> pull",   fun sticky_full_lifecycle/0}
        ]
    }.

cluster_projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"cluster emerged projects into event_clusters",         fun proj_cluster_emerged/0},
            {"cluster named updates name",                           fun proj_cluster_named/0},
            {"cluster dissolved updates status to dissolved",        fun proj_cluster_dissolved/0},
            {"cluster promoted updates status to promoted",          fun proj_cluster_promoted/0},
            {"cluster lifecycle: emerge -> name -> promote",         fun cluster_full_lifecycle/0}
        ]
    }.

arrow_projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"fact arrow drawn projects into fact_arrows",           fun proj_arrow_drawn/0},
            {"fact arrow erased deletes from fact_arrows",           fun proj_arrow_erased/0},
            {"fact arrow erased on nonexistent is harmless",         fun proj_arrow_erased_noop/0},
            {"multiple arrows for same storm",                       fun proj_multiple_arrows/0}
        ]
    }.

storm_session_projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"storm started projects into storm_sessions",           fun proj_storm_started/0},
            {"storm phase advanced updates phase",                   fun proj_storm_phase_advanced/0},
            {"storm shelved sets shelved_at",                        fun proj_storm_shelved/0},
            {"storm resumed clears shelved_at",                      fun proj_storm_resumed/0},
            {"storm archived sets completed_at",                     fun proj_storm_archived/0},
            {"storm lifecycle: start -> advance -> shelve -> resume -> archive", fun storm_full_lifecycle/0},
            {"multiple storms for same venture",                     fun proj_multiple_storms/0}
        ]
    }.

roundtrip_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"roundtrip: project storm then get_storm_state",        fun roundtrip_storm_state/0},
            {"roundtrip: empty storm state for unknown venture",     fun roundtrip_empty_storm_state/0}
        ]
    }.

%% ===================================================================
%% Setup / Cleanup
%% ===================================================================

setup() ->
    ok = filelib:ensure_dir("data/dummy"),
    %% Delete any leftover DB to ensure fresh state
    file:delete("data/query_venture_lifecycle.db"),
    file:delete("data/query_venture_lifecycle.db-wal"),
    file:delete("data/query_venture_lifecycle.db-shm"),
    {ok, _} = application:ensure_all_started(esqlite),
    {ok, Pid} = query_venture_lifecycle_store:start_link(),
    Pid.

cleanup(Pid) ->
    gen_server:stop(Pid),
    file:delete("data/query_venture_lifecycle.db"),
    file:delete("data/query_venture_lifecycle.db-wal"),
    file:delete("data/query_venture_lifecycle.db-shm"),
    ok.

%% ===================================================================
%% Helpers
%% ===================================================================

%% Extract a single-column value from fetchall result.
%% fetchall returns [[val], ...] for single-column queries (list of lists).
get_single_value(Rows) ->
    [[Val] | _] = Rows,
    Val.

sticky_event(StickyId, VentureId, StormNumber) ->
    #{
        sticky_id => StickyId,
        venture_id => VentureId,
        storm_number => StormNumber,
        text => <<"Something happened">>,
        author => <<"alice">>,
        created_at => 1000
    }.

cluster_event(ClusterId, VentureId, StormNumber) ->
    #{
        cluster_id => ClusterId,
        venture_id => VentureId,
        storm_number => StormNumber,
        color => <<"#FF6B6B">>,
        emerged_at => 2000
    }.

arrow_event(ArrowId, VentureId, StormNumber) ->
    #{
        arrow_id => ArrowId,
        venture_id => VentureId,
        storm_number => StormNumber,
        from_cluster => <<"cluster-a">>,
        to_cluster => <<"cluster-b">>,
        fact_name => <<"OrderPlaced">>,
        drawn_at => 3000
    }.

storm_event(VentureId, StormNumber) ->
    #{
        venture_id => VentureId,
        storm_number => StormNumber,
        started_at => 4000
    }.

%% ===================================================================
%% Sticky projection tests
%% ===================================================================

proj_sticky_posted() ->
    Event = sticky_event(<<"s-1">>, <<"v-test-1">>, 1),
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(Event),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT sticky_id, venture_id, storm_number, text, author, weight, "
        "stack_id, cluster_id, created_at FROM event_stickies", []),
    ?assertEqual(1, length(Rows)),
    [[StickyId, VentureId, StormNum, Text, Author, Weight,
      StackId, ClusterId, CreatedAt]] = Rows,
    ?assertEqual(<<"s-1">>, StickyId),
    ?assertEqual(<<"v-test-1">>, VentureId),
    ?assertEqual(1, StormNum),
    ?assertEqual(<<"Something happened">>, Text),
    ?assertEqual(<<"alice">>, Author),
    ?assertEqual(1, Weight),
    ?assertEqual(undefined, StackId),
    ?assertEqual(undefined, ClusterId),
    ?assertEqual(1000, CreatedAt).

proj_sticky_posted_defaults() ->
    %% When author is omitted, it should default to <<"user">>
    Event = #{
        sticky_id => <<"s-def">>,
        venture_id => <<"v-test-1">>,
        storm_number => 1,
        text => <<"Default author test">>,
        created_at => 5000
    },
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(Event),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT author FROM event_stickies WHERE sticky_id = ?1", [<<"s-def">>]),
    Author = get_single_value(Rows),
    ?assertEqual(<<"user">>, Author).

proj_sticky_pulled() ->
    %% First post a sticky
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        sticky_event(<<"s-pull">>, <<"v-test-1">>, 1)),
    %% Verify it exists
    {ok, Before} = query_venture_lifecycle_store:query(
        "SELECT sticky_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-pull">>]),
    ?assertEqual(1, length(Before)),
    %% Pull it
    ok = event_sticky_pulled_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-pull">>}),
    %% Verify it's gone
    {ok, After} = query_venture_lifecycle_store:query(
        "SELECT sticky_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-pull">>]),
    ?assertEqual(0, length(After)).

proj_sticky_pulled_noop() ->
    %% Pulling a nonexistent sticky should not fail
    ok = event_sticky_pulled_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-nonexistent">>}).

proj_sticky_stacked() ->
    %% Post a sticky first
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        sticky_event(<<"s-stack">>, <<"v-test-1">>, 1)),
    %% Stack it
    ok = event_sticky_stacked_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-stack">>, stack_id => <<"stack-abc">>}),
    %% Verify stack_id was set
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT stack_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-stack">>]),
    StackId = get_single_value(Rows),
    ?assertEqual(<<"stack-abc">>, StackId).

proj_sticky_unstacked() ->
    %% Post and stack a sticky
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        sticky_event(<<"s-unstack">>, <<"v-test-1">>, 1)),
    ok = event_sticky_stacked_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-unstack">>, stack_id => <<"stack-xyz">>}),
    %% Verify stack_id is set
    {ok, Before} = query_venture_lifecycle_store:query(
        "SELECT stack_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-unstack">>]),
    ?assertEqual(<<"stack-xyz">>, get_single_value(Before)),
    %% Unstack it
    ok = event_sticky_unstacked_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-unstack">>}),
    %% Verify stack_id is now NULL
    {ok, After} = query_venture_lifecycle_store:query(
        "SELECT stack_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-unstack">>]),
    ?assertEqual(undefined, get_single_value(After)).

proj_stack_groomed() ->
    %% Post three stickies: one canonical + two to be absorbed
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        sticky_event(<<"s-canon">>, <<"v-test-1">>, 1)),
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        (sticky_event(<<"s-abs-1">>, <<"v-test-1">>, 1))#{text => <<"Absorbed 1">>}),
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        (sticky_event(<<"s-abs-2">>, <<"v-test-1">>, 1))#{text => <<"Absorbed 2">>}),
    %% Stack them all together
    ok = event_sticky_stacked_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-canon">>, stack_id => <<"s-canon">>}),
    ok = event_sticky_stacked_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-abs-1">>, stack_id => <<"s-canon">>}),
    ok = event_sticky_stacked_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-abs-2">>, stack_id => <<"s-canon">>}),
    %% Groom the stack
    ok = event_stack_groomed_v1_to_sqlite_event_stickies:project(#{
        canonical_sticky_id => <<"s-canon">>,
        weight => 3,
        absorbed_sticky_ids => [<<"s-abs-1">>, <<"s-abs-2">>]
    }),
    %% Verify canonical sticky has weight=3 and stack_id=NULL
    {ok, CanonRows} = query_venture_lifecycle_store:query(
        "SELECT weight, stack_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-canon">>]),
    [[Weight, StackId]] = CanonRows,
    ?assertEqual(3, Weight),
    ?assertEqual(undefined, StackId),
    %% Verify absorbed stickies are deleted
    {ok, Abs1} = query_venture_lifecycle_store:query(
        "SELECT sticky_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-abs-1">>]),
    ?assertEqual(0, length(Abs1)),
    {ok, Abs2} = query_venture_lifecycle_store:query(
        "SELECT sticky_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-abs-2">>]),
    ?assertEqual(0, length(Abs2)).

proj_stack_groomed_empty_absorbed() ->
    %% Post a canonical sticky
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        sticky_event(<<"s-solo">>, <<"v-test-1">>, 1)),
    %% Groom with empty absorbed list (just weight update)
    ok = event_stack_groomed_v1_to_sqlite_event_stickies:project(#{
        canonical_sticky_id => <<"s-solo">>,
        weight => 5,
        absorbed_sticky_ids => []
    }),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT weight FROM event_stickies WHERE sticky_id = ?1", [<<"s-solo">>]),
    ?assertEqual(5, get_single_value(Rows)).

proj_sticky_clustered() ->
    %% Post a sticky
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        sticky_event(<<"s-clust">>, <<"v-test-1">>, 1)),
    %% Cluster it
    ok = event_sticky_clustered_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-clust">>, cluster_id => <<"cluster-red">>}),
    %% Verify
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT cluster_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-clust">>]),
    ?assertEqual(<<"cluster-red">>, get_single_value(Rows)).

proj_sticky_unclustered() ->
    %% Post and cluster a sticky
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        sticky_event(<<"s-unclust">>, <<"v-test-1">>, 1)),
    ok = event_sticky_clustered_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-unclust">>, cluster_id => <<"cluster-blue">>}),
    %% Verify it's clustered
    {ok, Before} = query_venture_lifecycle_store:query(
        "SELECT cluster_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-unclust">>]),
    ?assertEqual(<<"cluster-blue">>, get_single_value(Before)),
    %% Uncluster it
    ok = event_sticky_unclustered_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-unclust">>}),
    %% Verify cluster_id is NULL
    {ok, After} = query_venture_lifecycle_store:query(
        "SELECT cluster_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-unclust">>]),
    ?assertEqual(undefined, get_single_value(After)).

sticky_full_lifecycle() ->
    %% Post
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        sticky_event(<<"s-life">>, <<"v-test-1">>, 1)),
    %% Stack
    ok = event_sticky_stacked_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-life">>, stack_id => <<"stack-life">>}),
    {ok, R1} = query_venture_lifecycle_store:query(
        "SELECT stack_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-life">>]),
    ?assertEqual(<<"stack-life">>, get_single_value(R1)),
    %% Cluster
    ok = event_sticky_clustered_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-life">>, cluster_id => <<"cluster-life">>}),
    {ok, R2} = query_venture_lifecycle_store:query(
        "SELECT cluster_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-life">>]),
    ?assertEqual(<<"cluster-life">>, get_single_value(R2)),
    %% Pull (delete)
    ok = event_sticky_pulled_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-life">>}),
    {ok, R3} = query_venture_lifecycle_store:query(
        "SELECT sticky_id FROM event_stickies WHERE sticky_id = ?1", [<<"s-life">>]),
    ?assertEqual(0, length(R3)).

%% ===================================================================
%% Cluster projection tests
%% ===================================================================

proj_cluster_emerged() ->
    Event = cluster_event(<<"c-1">>, <<"v-test-1">>, 1),
    ok = event_cluster_emerged_v1_to_sqlite_event_clusters:project(Event),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT cluster_id, venture_id, storm_number, name, color, status, created_at "
        "FROM event_clusters", []),
    ?assertEqual(1, length(Rows)),
    [[ClusterId, VentureId, StormNum, Name, Color, Status, CreatedAt]] = Rows,
    ?assertEqual(<<"c-1">>, ClusterId),
    ?assertEqual(<<"v-test-1">>, VentureId),
    ?assertEqual(1, StormNum),
    ?assertEqual(undefined, Name),
    ?assertEqual(<<"#FF6B6B">>, Color),
    ?assertEqual(<<"active">>, Status),
    ?assertEqual(2000, CreatedAt).

proj_cluster_named() ->
    %% First emerge a cluster
    ok = event_cluster_emerged_v1_to_sqlite_event_clusters:project(
        cluster_event(<<"c-name">>, <<"v-test-1">>, 1)),
    %% Name it
    ok = event_cluster_named_v1_to_sqlite_event_clusters:project(
        #{cluster_id => <<"c-name">>, name => <<"Order Processing">>}),
    %% Verify
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT name FROM event_clusters WHERE cluster_id = ?1", [<<"c-name">>]),
    ?assertEqual(<<"Order Processing">>, get_single_value(Rows)).

proj_cluster_dissolved() ->
    %% First emerge a cluster
    ok = event_cluster_emerged_v1_to_sqlite_event_clusters:project(
        cluster_event(<<"c-dissolve">>, <<"v-test-1">>, 1)),
    %% Verify initial status
    {ok, Before} = query_venture_lifecycle_store:query(
        "SELECT status FROM event_clusters WHERE cluster_id = ?1", [<<"c-dissolve">>]),
    ?assertEqual(<<"active">>, get_single_value(Before)),
    %% Dissolve it
    ok = event_cluster_dissolved_v1_to_sqlite_event_clusters:project(
        #{cluster_id => <<"c-dissolve">>}),
    %% Verify status changed
    {ok, After} = query_venture_lifecycle_store:query(
        "SELECT status FROM event_clusters WHERE cluster_id = ?1", [<<"c-dissolve">>]),
    ?assertEqual(<<"dissolved">>, get_single_value(After)).

proj_cluster_promoted() ->
    %% First emerge a cluster
    ok = event_cluster_emerged_v1_to_sqlite_event_clusters:project(
        cluster_event(<<"c-promote">>, <<"v-test-1">>, 1)),
    %% Promote it
    ok = event_cluster_promoted_v1_to_sqlite_event_clusters:project(
        #{cluster_id => <<"c-promote">>}),
    %% Verify
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT status FROM event_clusters WHERE cluster_id = ?1", [<<"c-promote">>]),
    ?assertEqual(<<"promoted">>, get_single_value(Rows)).

cluster_full_lifecycle() ->
    %% Emerge
    ok = event_cluster_emerged_v1_to_sqlite_event_clusters:project(
        cluster_event(<<"c-life">>, <<"v-test-1">>, 1)),
    {ok, R1} = query_venture_lifecycle_store:query(
        "SELECT status FROM event_clusters WHERE cluster_id = ?1", [<<"c-life">>]),
    ?assertEqual(<<"active">>, get_single_value(R1)),
    %% Name
    ok = event_cluster_named_v1_to_sqlite_event_clusters:project(
        #{cluster_id => <<"c-life">>, name => <<"Payments">>}),
    {ok, R2} = query_venture_lifecycle_store:query(
        "SELECT name FROM event_clusters WHERE cluster_id = ?1", [<<"c-life">>]),
    ?assertEqual(<<"Payments">>, get_single_value(R2)),
    %% Promote
    ok = event_cluster_promoted_v1_to_sqlite_event_clusters:project(
        #{cluster_id => <<"c-life">>}),
    {ok, R3} = query_venture_lifecycle_store:query(
        "SELECT status FROM event_clusters WHERE cluster_id = ?1", [<<"c-life">>]),
    ?assertEqual(<<"promoted">>, get_single_value(R3)).

%% ===================================================================
%% Fact arrow projection tests
%% ===================================================================

proj_arrow_drawn() ->
    Event = arrow_event(<<"a-1">>, <<"v-test-1">>, 1),
    ok = fact_arrow_drawn_v1_to_sqlite_fact_arrows:project(Event),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT arrow_id, venture_id, storm_number, from_cluster, to_cluster, "
        "fact_name, created_at FROM fact_arrows", []),
    ?assertEqual(1, length(Rows)),
    [[ArrowId, VentureId, StormNum, FromC, ToC, FactName, CreatedAt]] = Rows,
    ?assertEqual(<<"a-1">>, ArrowId),
    ?assertEqual(<<"v-test-1">>, VentureId),
    ?assertEqual(1, StormNum),
    ?assertEqual(<<"cluster-a">>, FromC),
    ?assertEqual(<<"cluster-b">>, ToC),
    ?assertEqual(<<"OrderPlaced">>, FactName),
    ?assertEqual(3000, CreatedAt).

proj_arrow_erased() ->
    %% Draw an arrow
    ok = fact_arrow_drawn_v1_to_sqlite_fact_arrows:project(
        arrow_event(<<"a-erase">>, <<"v-test-1">>, 1)),
    %% Verify it exists
    {ok, Before} = query_venture_lifecycle_store:query(
        "SELECT arrow_id FROM fact_arrows WHERE arrow_id = ?1", [<<"a-erase">>]),
    ?assertEqual(1, length(Before)),
    %% Erase it
    ok = fact_arrow_erased_v1_to_sqlite_fact_arrows:project(
        #{arrow_id => <<"a-erase">>}),
    %% Verify it's gone
    {ok, After} = query_venture_lifecycle_store:query(
        "SELECT arrow_id FROM fact_arrows WHERE arrow_id = ?1", [<<"a-erase">>]),
    ?assertEqual(0, length(After)).

proj_arrow_erased_noop() ->
    %% Erasing nonexistent arrow should not fail
    ok = fact_arrow_erased_v1_to_sqlite_fact_arrows:project(
        #{arrow_id => <<"a-nonexistent">>}).

proj_multiple_arrows() ->
    A1 = arrow_event(<<"a-m1">>, <<"v-test-1">>, 1),
    A2 = (arrow_event(<<"a-m2">>, <<"v-test-1">>, 1))#{
        from_cluster => <<"cluster-b">>,
        to_cluster => <<"cluster-c">>,
        fact_name => <<"PaymentProcessed">>
    },
    A3 = (arrow_event(<<"a-m3">>, <<"v-test-1">>, 1))#{
        from_cluster => <<"cluster-c">>,
        to_cluster => <<"cluster-a">>,
        fact_name => <<"ShipmentScheduled">>
    },
    ok = fact_arrow_drawn_v1_to_sqlite_fact_arrows:project(A1),
    ok = fact_arrow_drawn_v1_to_sqlite_fact_arrows:project(A2),
    ok = fact_arrow_drawn_v1_to_sqlite_fact_arrows:project(A3),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT arrow_id FROM fact_arrows WHERE venture_id = ?1 AND storm_number = ?2",
        [<<"v-test-1">>, 1]),
    ?assertEqual(3, length(Rows)).

%% ===================================================================
%% Storm session projection tests
%% ===================================================================

proj_storm_started() ->
    Event = storm_event(<<"v-test-1">>, 1),
    ok = big_picture_storm_started_v1_to_sqlite_storm_sessions:project(Event),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT venture_id, storm_number, phase, started_at, shelved_at, completed_at "
        "FROM storm_sessions", []),
    ?assertEqual(1, length(Rows)),
    [[VentureId, StormNum, Phase, StartedAt, ShelvedAt, CompletedAt]] = Rows,
    ?assertEqual(<<"v-test-1">>, VentureId),
    ?assertEqual(1, StormNum),
    ?assertEqual(<<"storm">>, Phase),
    ?assertEqual(4000, StartedAt),
    ?assertEqual(undefined, ShelvedAt),
    ?assertEqual(undefined, CompletedAt).

proj_storm_phase_advanced() ->
    %% Start a storm first
    ok = big_picture_storm_started_v1_to_sqlite_storm_sessions:project(
        storm_event(<<"v-test-1">>, 1)),
    %% Advance phase
    ok = storm_phase_advanced_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-test-1">>, phase => <<"cluster">>}),
    %% Verify
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT phase FROM storm_sessions WHERE venture_id = ?1 AND storm_number = ?2",
        [<<"v-test-1">>, 1]),
    ?assertEqual(<<"cluster">>, get_single_value(Rows)).

proj_storm_shelved() ->
    %% Start a storm first
    ok = big_picture_storm_started_v1_to_sqlite_storm_sessions:project(
        storm_event(<<"v-test-1">>, 1)),
    %% Shelve it
    ok = big_picture_storm_shelved_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-test-1">>, shelved_at => 5000}),
    %% Verify
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT shelved_at FROM storm_sessions WHERE venture_id = ?1 AND storm_number = ?2",
        [<<"v-test-1">>, 1]),
    ?assertEqual(5000, get_single_value(Rows)).

proj_storm_resumed() ->
    %% Start and shelve a storm
    ok = big_picture_storm_started_v1_to_sqlite_storm_sessions:project(
        storm_event(<<"v-test-1">>, 1)),
    ok = big_picture_storm_shelved_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-test-1">>, shelved_at => 5000}),
    %% Verify it's shelved
    {ok, Before} = query_venture_lifecycle_store:query(
        "SELECT shelved_at FROM storm_sessions WHERE venture_id = ?1 AND storm_number = ?2",
        [<<"v-test-1">>, 1]),
    ?assertEqual(5000, get_single_value(Before)),
    %% Resume it
    ok = big_picture_storm_resumed_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-test-1">>}),
    %% Verify shelved_at is NULL
    {ok, After} = query_venture_lifecycle_store:query(
        "SELECT shelved_at FROM storm_sessions WHERE venture_id = ?1 AND storm_number = ?2",
        [<<"v-test-1">>, 1]),
    ?assertEqual(undefined, get_single_value(After)).

proj_storm_archived() ->
    %% Start a storm first
    ok = big_picture_storm_started_v1_to_sqlite_storm_sessions:project(
        storm_event(<<"v-test-1">>, 1)),
    %% Archive it
    ok = big_picture_storm_archived_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-test-1">>, archived_at => 9000}),
    %% Verify completed_at is set
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT completed_at FROM storm_sessions WHERE venture_id = ?1 AND storm_number = ?2",
        [<<"v-test-1">>, 1]),
    ?assertEqual(9000, get_single_value(Rows)).

storm_full_lifecycle() ->
    %% Start
    ok = big_picture_storm_started_v1_to_sqlite_storm_sessions:project(
        storm_event(<<"v-life">>, 1)),
    {ok, R1} = query_venture_lifecycle_store:query(
        "SELECT phase FROM storm_sessions WHERE venture_id = ?1", [<<"v-life">>]),
    ?assertEqual(<<"storm">>, get_single_value(R1)),
    %% Advance to cluster phase
    ok = storm_phase_advanced_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-life">>, phase => <<"cluster">>}),
    {ok, R2} = query_venture_lifecycle_store:query(
        "SELECT phase FROM storm_sessions WHERE venture_id = ?1", [<<"v-life">>]),
    ?assertEqual(<<"cluster">>, get_single_value(R2)),
    %% Shelve
    ok = big_picture_storm_shelved_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-life">>, shelved_at => 6000}),
    {ok, R3} = query_venture_lifecycle_store:query(
        "SELECT shelved_at FROM storm_sessions WHERE venture_id = ?1", [<<"v-life">>]),
    ?assertEqual(6000, get_single_value(R3)),
    %% Resume
    ok = big_picture_storm_resumed_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-life">>}),
    {ok, R4} = query_venture_lifecycle_store:query(
        "SELECT shelved_at FROM storm_sessions WHERE venture_id = ?1", [<<"v-life">>]),
    ?assertEqual(undefined, get_single_value(R4)),
    %% Archive
    ok = big_picture_storm_archived_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-life">>, archived_at => 9999}),
    {ok, R5} = query_venture_lifecycle_store:query(
        "SELECT completed_at FROM storm_sessions WHERE venture_id = ?1", [<<"v-life">>]),
    ?assertEqual(9999, get_single_value(R5)).

proj_multiple_storms() ->
    %% Start two storms for the same venture
    ok = big_picture_storm_started_v1_to_sqlite_storm_sessions:project(
        storm_event(<<"v-multi">>, 1)),
    ok = big_picture_storm_started_v1_to_sqlite_storm_sessions:project(
        (storm_event(<<"v-multi">>, 2))#{started_at => 8000}),
    %% Verify both exist
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT storm_number FROM storm_sessions WHERE venture_id = ?1 "
        "ORDER BY storm_number ASC", [<<"v-multi">>]),
    ?assertEqual(2, length(Rows)),
    [[1], [2]] = Rows,
    %% Phase advance should update the latest storm (storm_number=2)
    ok = storm_phase_advanced_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-multi">>, phase => <<"narrate">>}),
    {ok, PhaseRows} = query_venture_lifecycle_store:query(
        "SELECT phase FROM storm_sessions WHERE venture_id = ?1 "
        "ORDER BY storm_number ASC", [<<"v-multi">>]),
    %% Storm 1 should still be 'storm', storm 2 should be 'narrate'
    [[Phase1], [Phase2]] = PhaseRows,
    ?assertEqual(<<"storm">>, Phase1),
    ?assertEqual(<<"narrate">>, Phase2).

%% ===================================================================
%% Roundtrip tests: project -> query via get_storm_state
%% ===================================================================

roundtrip_storm_state() ->
    %% Start a storm session
    ok = big_picture_storm_started_v1_to_sqlite_storm_sessions:project(
        storm_event(<<"v-rt">>, 1)),
    %% Post stickies
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        sticky_event(<<"s-rt-1">>, <<"v-rt">>, 1)),
    ok = event_sticky_posted_v1_to_sqlite_event_stickies:project(
        (sticky_event(<<"s-rt-2">>, <<"v-rt">>, 1))#{text => <<"Another event">>}),
    %% Emerge a cluster
    ok = event_cluster_emerged_v1_to_sqlite_event_clusters:project(
        cluster_event(<<"c-rt-1">>, <<"v-rt">>, 1)),
    ok = event_cluster_named_v1_to_sqlite_event_clusters:project(
        #{cluster_id => <<"c-rt-1">>, name => <<"Auth">>}),
    %% Emerge another cluster
    ok = event_cluster_emerged_v1_to_sqlite_event_clusters:project(
        (cluster_event(<<"c-rt-2">>, <<"v-rt">>, 1))#{color => <<"#4ECDC4">>}),
    %% Draw an arrow
    ok = fact_arrow_drawn_v1_to_sqlite_fact_arrows:project(
        (arrow_event(<<"a-rt-1">>, <<"v-rt">>, 1))#{
            from_cluster => <<"c-rt-1">>,
            to_cluster => <<"c-rt-2">>,
            fact_name => <<"UserAuthenticated">>
        }),
    %% Cluster a sticky
    ok = event_sticky_clustered_v1_to_sqlite_event_stickies:project(
        #{sticky_id => <<"s-rt-1">>, cluster_id => <<"c-rt-1">>}),
    %% Advance phase
    ok = storm_phase_advanced_v1_to_sqlite_storm_sessions:project(
        #{venture_id => <<"v-rt">>, phase => <<"cluster">>}),
    %% Query via get_storm_state
    {ok, State} = get_storm_state:get(<<"v-rt">>),
    ?assertEqual(<<"cluster">>, maps:get(phase, State)),
    ?assertEqual(1, maps:get(storm_number, State)),
    ?assertEqual(4000, maps:get(started_at, State)),
    ?assertEqual(undefined, maps:get(shelved_at, State)),
    %% Verify stickies
    Stickies = maps:get(stickies, State),
    ?assertEqual(2, length(Stickies)),
    %% Find the clustered sticky
    ClusteredSticky = lists:keyfind(<<"s-rt-1">>, 2,
        [{maps:get(sticky_id, S), maps:get(sticky_id, S)} || S <- Stickies]),
    ?assertNotEqual(false, ClusteredSticky),
    %% Verify clusters
    Clusters = maps:get(clusters, State),
    ?assertEqual(2, length(Clusters)),
    %% Verify arrows
    Arrows = maps:get(arrows, State),
    ?assertEqual(1, length(Arrows)),
    [Arrow] = Arrows,
    ?assertEqual(<<"a-rt-1">>, maps:get(arrow_id, Arrow)),
    ?assertEqual(<<"c-rt-1">>, maps:get(from_cluster, Arrow)),
    ?assertEqual(<<"c-rt-2">>, maps:get(to_cluster, Arrow)),
    ?assertEqual(<<"UserAuthenticated">>, maps:get(fact_name, Arrow)).

roundtrip_empty_storm_state() ->
    %% Query for a venture with no storm sessions
    {ok, State} = get_storm_state:get(<<"v-nonexistent">>),
    ?assertEqual(<<"ready">>, maps:get(phase, State)),
    ?assertEqual(0, maps:get(storm_number, State)),
    ?assertEqual([], maps:get(stickies, State)),
    ?assertEqual([], maps:get(clusters, State)),
    ?assertEqual([], maps:get(arrows, State)).
