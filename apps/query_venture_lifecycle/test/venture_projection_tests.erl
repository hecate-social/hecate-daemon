%%% @doc Tests for venture lifecycle projections (event -> SQLite writes).
%%%
%%% Uses a temp SQLite database via query_venture_lifecycle_store.
%%% Each test group gets a fresh database (foreach pattern).
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
%%%   Single-column: [val, ...]
-module(venture_projection_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_venture_lifecycle/include/venture_lifecycle_status.hrl").
-include_lib("reckon_gater/include/esdb_gater_types.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"venture_initiated projects into ventures",         fun proj_venture_initiated/0},
            {"discovery_started sets DISCOVERING flag",          fun proj_discovery_started/0},
            {"discovery_completed toggles flags",                fun proj_discovery_completed/0},
            {"venture_archived sets ARCHIVED flag",              fun proj_venture_archived/0},
            {"division_identified projects into discovered_divisions", fun proj_division_identified/0},
            {"multiple divisions for same venture",              fun proj_multiple_divisions/0},
            {"status label recomputed on flag change",           fun proj_status_label_recomputed/0},
            {"roundtrip: project venture then query by id",      fun roundtrip_venture_by_id/0},
            {"roundtrip: project venture then query page",       fun roundtrip_venture_page/0},
            {"roundtrip: project divisions then query page",     fun roundtrip_divisions_page/0},
            {"roundtrip: archived venture excluded from active", fun roundtrip_archived_not_active/0},
            {"raw #event{} record crashes project/1 (the bug)", fun raw_record_crashes_project/0},
            {"#event{} via projection_event:to_map projects correctly", fun record_via_to_map_projects/0}
        ]
    }.

%% ===================================================================
%% Setup / Cleanup
%% ===================================================================

setup() ->
    %% Delete any leftover DB to ensure fresh state
    file:delete(shared_paths:db_path("query_venture_lifecycle.db")),
    file:delete(shared_paths:db_path("query_venture_lifecycle.db-wal")),
    file:delete(shared_paths:db_path("query_venture_lifecycle.db-shm")),
    {ok, _} = application:ensure_all_started(esqlite),
    {ok, Pid} = query_venture_lifecycle_store:start_link(),
    Pid.

cleanup(Pid) ->
    gen_server:stop(Pid),
    file:delete(shared_paths:db_path("query_venture_lifecycle.db")),
    file:delete(shared_paths:db_path("query_venture_lifecycle.db-wal")),
    file:delete(shared_paths:db_path("query_venture_lifecycle.db-shm")),
    ok.

%% ===================================================================
%% Helpers
%% ===================================================================

initiated_event(VentureId) ->
    #{
        venture_id => VentureId,
        name => <<"Test Venture">>,
        brief => <<"A test venture">>,
        repos => [<<"repo1">>, <<"repo2">>],
        skills => [<<"erlang">>, <<"go">>],
        context_map => #{<<"domain">> => <<"test">>},
        initiated_by => <<"user@test">>,
        initiated_at => 1000
    }.

%% Extract a single-column value from fetchall result.
%% fetchall returns [[val], ...] for single-column queries (list of lists).
get_single_value(Rows) ->
    [[Val] | _] = Rows,
    Val.

%% ===================================================================
%% Projection tests
%% ===================================================================

proj_venture_initiated() ->
    EventData = initiated_event(<<"v-test-1">>),
    ok = venture_initiated_v1_to_sqlite_ventures:project(EventData),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT venture_id, name, brief, status, status_label, "
        "repos, skills, context_map, initiated_at, initiated_by "
        "FROM ventures", []),
    ?assertEqual(1, length(Rows)),
    %% fetchall returns [[col1, col2, ...]] for multi-column
    [[VId, Name, Brief, Status, _Label, ReposJson, SkillsJson, CtxJson, InitAt, InitBy]] = Rows,
    ?assertEqual(<<"v-test-1">>, VId),
    ?assertEqual(<<"Test Venture">>, Name),
    ?assertEqual(<<"A test venture">>, Brief),
    ?assertEqual(?VL_INITIATED, Status),
    ?assertEqual(1000, InitAt),
    ?assertEqual(<<"user@test">>, InitBy),
    %% JSON-encoded fields
    ?assertEqual([<<"repo1">>, <<"repo2">>], json:decode(ReposJson)),
    ?assertEqual([<<"erlang">>, <<"go">>], json:decode(SkillsJson)),
    ?assertEqual(#{<<"domain">> => <<"test">>}, json:decode(CtxJson)).

proj_discovery_started() ->
    %% Must project initiated first (row must exist for UPDATE)
    ok = venture_initiated_v1_to_sqlite_ventures:project(initiated_event(<<"v-test-1">>)),
    %% Then project discovery_started
    ok = discovery_started_v1_to_sqlite_ventures:project(#{
        venture_id => <<"v-test-1">>
    }),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT status FROM ventures WHERE venture_id = ?1", [<<"v-test-1">>]),
    Status = get_single_value(Rows),
    ?assert(Status band ?VL_DISCOVERING =/= 0),
    ?assert(Status band ?VL_INITIATED =/= 0).

proj_discovery_completed() ->
    %% Setup: initiate + start discovery
    ok = venture_initiated_v1_to_sqlite_ventures:project(initiated_event(<<"v-test-1">>)),
    ok = discovery_started_v1_to_sqlite_ventures:project(#{venture_id => <<"v-test-1">>}),
    %% Complete discovery
    ok = discovery_completed_v1_to_sqlite_ventures:project(#{venture_id => <<"v-test-1">>}),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT status FROM ventures WHERE venture_id = ?1", [<<"v-test-1">>]),
    Status = get_single_value(Rows),
    %% DISCOVERING should be unset, DISCOVERY_COMPLETED should be set
    ?assert(Status band ?VL_DISCOVERING =:= 0),
    ?assert(Status band ?VL_DISCOVERY_COMPLETED =/= 0),
    ?assert(Status band ?VL_INITIATED =/= 0).

proj_venture_archived() ->
    ok = venture_initiated_v1_to_sqlite_ventures:project(initiated_event(<<"v-test-1">>)),
    ok = venture_archived_v1_to_sqlite_ventures:project(#{venture_id => <<"v-test-1">>}),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT status FROM ventures WHERE venture_id = ?1", [<<"v-test-1">>]),
    Status = get_single_value(Rows),
    ?assert(Status band ?VL_ARCHIVED =/= 0),
    ?assert(Status band ?VL_INITIATED =/= 0).

proj_division_identified() ->
    EventData = #{
        division_id => <<"div-abc">>,
        venture_id => <<"v-test-1">>,
        context_name => <<"auth_division">>,
        description => <<"Authentication & Authorization">>,
        identified_by => <<"user@test">>,
        identified_at => 2000
    },
    ok = division_identified_v1_to_sqlite_discovered_divisions:project(EventData),
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT division_id, venture_id, context_name, description, "
        "identified_by, discovered_at FROM discovered_divisions", []),
    ?assertEqual(1, length(Rows)),
    [[DivId, VId, CtxName, Desc, IdBy, DiscAt]] = Rows,
    ?assertEqual(<<"div-abc">>, DivId),
    ?assertEqual(<<"v-test-1">>, VId),
    ?assertEqual(<<"auth_division">>, CtxName),
    ?assertEqual(<<"Authentication & Authorization">>, Desc),
    ?assertEqual(<<"user@test">>, IdBy),
    ?assertEqual(2000, DiscAt).

proj_multiple_divisions() ->
    Div1 = #{division_id => <<"div-1">>, venture_id => <<"v-test-1">>,
             context_name => <<"auth">>, description => <<"Auth">>,
             identified_by => <<"user">>, identified_at => 1000},
    Div2 = #{division_id => <<"div-2">>, venture_id => <<"v-test-1">>,
             context_name => <<"payments">>, description => <<"Pay">>,
             identified_by => <<"user">>, identified_at => 2000},
    Div3 = #{division_id => <<"div-3">>, venture_id => <<"v-test-2">>,
             context_name => <<"billing">>, description => <<"Bill">>,
             identified_by => <<"user">>, identified_at => 3000},
    ok = division_identified_v1_to_sqlite_discovered_divisions:project(Div1),
    ok = division_identified_v1_to_sqlite_discovered_divisions:project(Div2),
    ok = division_identified_v1_to_sqlite_discovered_divisions:project(Div3),
    %% Query divisions for v-test-1 only
    {ok, RowsV1} = query_venture_lifecycle_store:query(
        "SELECT division_id FROM discovered_divisions WHERE venture_id = ?1",
        [<<"v-test-1">>]),
    ?assertEqual(2, length(RowsV1)),
    %% Query divisions for v-test-2
    {ok, RowsV2} = query_venture_lifecycle_store:query(
        "SELECT division_id FROM discovered_divisions WHERE venture_id = ?1",
        [<<"v-test-2">>]),
    ?assertEqual(1, length(RowsV2)).

proj_status_label_recomputed() ->
    ok = venture_initiated_v1_to_sqlite_ventures:project(initiated_event(<<"v-test-1">>)),
    %% After initiation, label should contain "Initiated"
    {ok, Labels1} = query_venture_lifecycle_store:query(
        "SELECT status_label FROM ventures WHERE venture_id = ?1", [<<"v-test-1">>]),
    Label1 = get_single_value(Labels1),
    ?assertNotEqual(nomatch, binary:match(Label1, <<"Initiated">>)),
    %% After archiving, label should also contain "Archived"
    ok = venture_archived_v1_to_sqlite_ventures:project(#{venture_id => <<"v-test-1">>}),
    {ok, Labels2} = query_venture_lifecycle_store:query(
        "SELECT status_label FROM ventures WHERE venture_id = ?1", [<<"v-test-1">>]),
    Label2 = get_single_value(Labels2),
    ?assertNotEqual(nomatch, binary:match(Label2, <<"Archived">>)).

%% ===================================================================
%% Roundtrip tests: project -> query via query desk modules
%% ===================================================================

roundtrip_venture_by_id() ->
    ok = venture_initiated_v1_to_sqlite_ventures:project(initiated_event(<<"v-rt-1">>)),
    {ok, Venture} = get_venture_by_id:get(<<"v-rt-1">>),
    ?assertEqual(<<"v-rt-1">>, maps:get(venture_id, Venture)),
    ?assertEqual(<<"Test Venture">>, maps:get(name, Venture)),
    ?assertEqual(<<"A test venture">>, maps:get(brief, Venture)),
    ?assertEqual(?VL_INITIATED, maps:get(status, Venture)),
    ?assertEqual([<<"repo1">>, <<"repo2">>], maps:get(repos, Venture)),
    ?assertEqual([<<"erlang">>, <<"go">>], maps:get(skills, Venture)),
    ?assertEqual(#{<<"domain">> => <<"test">>}, maps:get(context_map, Venture)),
    ?assertEqual(1000, maps:get(initiated_at, Venture)),
    ?assertEqual(<<"user@test">>, maps:get(initiated_by, Venture)).

roundtrip_venture_page() ->
    ok = venture_initiated_v1_to_sqlite_ventures:project(
        (initiated_event(<<"v-page-1">>))#{name => <<"First">>, initiated_at => 1000}),
    ok = venture_initiated_v1_to_sqlite_ventures:project(
        (initiated_event(<<"v-page-2">>))#{name => <<"Second">>, initiated_at => 2000}),
    {ok, Ventures} = get_ventures_page:get(#{limit => 10, offset => 0}),
    ?assertEqual(2, length(Ventures)),
    %% Ordered by initiated_at DESC
    [V1, V2] = Ventures,
    ?assertEqual(<<"v-page-2">>, maps:get(venture_id, V1)),
    ?assertEqual(<<"v-page-1">>, maps:get(venture_id, V2)).

roundtrip_divisions_page() ->
    Div1 = #{division_id => <<"div-rt-1">>, venture_id => <<"v-rt-1">>,
             context_name => <<"auth">>, description => <<"Auth module">>,
             identified_by => <<"user@test">>, identified_at => 1000},
    Div2 = #{division_id => <<"div-rt-2">>, venture_id => <<"v-rt-1">>,
             context_name => <<"payments">>, description => <<"Pay module">>,
             identified_by => <<"user@test">>, identified_at => 2000},
    ok = division_identified_v1_to_sqlite_discovered_divisions:project(Div1),
    ok = division_identified_v1_to_sqlite_discovered_divisions:project(Div2),
    {ok, Divisions} = get_discovered_divisions_page:get(#{
        venture_id => <<"v-rt-1">>, limit => 50, offset => 0
    }),
    ?assertEqual(2, length(Divisions)),
    %% Ordered by discovered_at DESC
    [D1, D2] = Divisions,
    ?assertEqual(<<"div-rt-2">>, maps:get(division_id, D1)),
    ?assertEqual(<<"div-rt-1">>, maps:get(division_id, D2)),
    ?assertEqual(<<"payments">>, maps:get(context_name, D1)),
    ?assertEqual(<<"auth">>, maps:get(context_name, D2)).

roundtrip_archived_not_active() ->
    %% Project a venture and archive it
    ok = venture_initiated_v1_to_sqlite_ventures:project(initiated_event(<<"v-arch-1">>)),
    ok = venture_archived_v1_to_sqlite_ventures:project(#{venture_id => <<"v-arch-1">>}),
    %% get_venture_by_id still finds it (includes archived)
    {ok, V} = get_venture_by_id:get(<<"v-arch-1">>),
    ?assert(maps:get(status, V) band ?VL_ARCHIVED =/= 0),
    %% Verify archived flag is set via raw query
    {ok, StatusRows} = query_venture_lifecycle_store:query(
        "SELECT status FROM ventures WHERE venture_id = ?1 AND (status & ?2) != 0",
        [<<"v-arch-1">>, ?VL_ARCHIVED]),
    Status = get_single_value(StatusRows),
    ?assert(Status band ?VL_ARCHIVED =/= 0).

%% ===================================================================
%% Bug proof: #event{} record vs flat map
%% ===================================================================

%% Helper: wrap business data in an #event{} record (as ReckonDB delivers)
wrap_in_event_record(EventData) ->
    #event{
        event_id = <<"evt-bug-test">>,
        event_type = <<"venture_initiated_v1">>,
        stream_id = <<"venture_aggregate-v-record-1">>,
        version = 0,
        data = EventData,
        metadata = #{},
        timestamp = 1000,
        epoch_us = 1000000
    }.

raw_record_crashes_project() ->
    %% This proves the bug: passing an #event{} record to project/1
    %% crashes with badarg because project/1 calls maps:find on a tuple.
    EventData = initiated_event(<<"v-record-1">>),
    EventRecord = wrap_in_event_record(EventData),
    %% OTP 28+ raises {badmap, _} instead of badarg
    ?assertError({badmap, _}, venture_initiated_v1_to_sqlite_ventures:project(EventRecord)).

record_via_to_map_projects() ->
    %% This proves the fix: projection_event:to_map/1 converts #event{}
    %% to a flat map that project/1 can consume.
    EventData = initiated_event(<<"v-record-2">>),
    EventRecord = wrap_in_event_record(EventData),
    FlatMap = projection_event:to_map(EventRecord),
    ok = venture_initiated_v1_to_sqlite_ventures:project(FlatMap),
    %% Verify it actually projected to SQLite
    {ok, Rows} = query_venture_lifecycle_store:query(
        "SELECT venture_id, name FROM ventures WHERE venture_id = ?1",
        [<<"v-record-2">>]),
    ?assertEqual(1, length(Rows)),
    [[VId, Name]] = Rows,
    ?assertEqual(<<"v-record-2">>, VId),
    ?assertEqual(<<"Test Venture">>, Name).
