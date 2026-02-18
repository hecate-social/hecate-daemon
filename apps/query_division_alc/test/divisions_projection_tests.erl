%%% @doc Tests for division ALC lifecycle projections (event -> SQLite writes).
%%%
%%% Tests projection modules that write to the `divisions` table, plus
%%% roundtrip tests via query desk modules (get_division_by_id, get_divisions_page,
%%% get_divisions_by_venture).
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
%%%   Single-column: [[val], ...]
-module(divisions_projection_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_division_alc/include/division_alc_status.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"division_initiated projects into divisions",             fun proj_initiated/0},
            {"division_archived sets DA_ARCHIVED flag",                fun proj_archived/0},
            {"phase_started updates dna_status to PHASE_ACTIVE",      fun proj_phase_started/0},
            {"phase_completed updates dna_status to PHASE_COMPLETED", fun proj_phase_completed/0},
            {"roundtrip: project then get_division_by_id",            fun roundtrip_by_id/0},
            {"roundtrip: project 2 divisions then get_divisions_page", fun roundtrip_page/0},
            {"roundtrip: get_divisions_by_venture filters correctly", fun roundtrip_by_venture/0}
        ]
    }.

%% ===================================================================
%% Setup / Cleanup
%% ===================================================================

setup() ->
    file:delete(shared_paths:sqlite_path("query_division_alc.db")),
    file:delete(shared_paths:sqlite_path("query_division_alc.db-wal")),
    file:delete(shared_paths:sqlite_path("query_division_alc.db-shm")),
    {ok, _} = application:ensure_all_started(esqlite),
    {ok, Pid} = query_division_alc_store:start_link(),
    Pid.

cleanup(Pid) ->
    gen_server:stop(Pid),
    file:delete(shared_paths:sqlite_path("query_division_alc.db")),
    file:delete(shared_paths:sqlite_path("query_division_alc.db-wal")),
    file:delete(shared_paths:sqlite_path("query_division_alc.db-shm")),
    ok.

%% ===================================================================
%% Helpers
%% ===================================================================

initiated_event(DivisionId, VentureId) ->
    #{
        division_id => DivisionId,
        venture_id => VentureId,
        context_name => <<"auth">>,
        initiated_at => 1000,
        initiated_by => <<"user@test">>
    }.

%% ===================================================================
%% Projection tests
%% ===================================================================

proj_initiated() ->
    Event = initiated_event(<<"div-1">>, <<"v-1">>),
    ok = division_initiated_v1_to_sqlite_divisions:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT division_id, venture_id, context_name, overall_status "
        "FROM divisions", []),
    ?assertEqual(1, length(Rows)),
    [[DivId, VId, CtxName, OverallStatus]] = Rows,
    ?assertEqual(<<"div-1">>, DivId),
    ?assertEqual(<<"v-1">>, VId),
    ?assertEqual(<<"auth">>, CtxName),
    ?assertEqual(?DA_INITIATED, OverallStatus).

proj_archived() ->
    ok = division_initiated_v1_to_sqlite_divisions:project(
        initiated_event(<<"div-1">>, <<"v-1">>)),
    ok = division_archived_v1_to_sqlite_divisions:project(#{
        division_id => <<"div-1">>
    }),
    {ok, [[OverallStatus]]} = query_division_alc_store:query(
        "SELECT overall_status FROM divisions WHERE division_id = ?1",
        [<<"div-1">>]),
    ?assert(OverallStatus band ?DA_ARCHIVED =/= 0).

proj_phase_started() ->
    ok = division_initiated_v1_to_sqlite_divisions:project(
        initiated_event(<<"div-1">>, <<"v-1">>)),
    ok = phase_started_v1_to_sqlite_divisions:project(#{
        division_id => <<"div-1">>,
        phase => <<"dna">>,
        started_at => 2000
    }),
    {ok, [[DnaStatus]]} = query_division_alc_store:query(
        "SELECT dna_status FROM divisions WHERE division_id = ?1",
        [<<"div-1">>]),
    ?assertEqual(?PHASE_ACTIVE, DnaStatus).

proj_phase_completed() ->
    ok = division_initiated_v1_to_sqlite_divisions:project(
        initiated_event(<<"div-1">>, <<"v-1">>)),
    ok = phase_started_v1_to_sqlite_divisions:project(#{
        division_id => <<"div-1">>,
        phase => <<"dna">>,
        started_at => 2000
    }),
    ok = phase_completed_v1_to_sqlite_divisions:project(#{
        division_id => <<"div-1">>,
        phase => <<"dna">>,
        completed_at => 3000
    }),
    {ok, [[DnaStatus]]} = query_division_alc_store:query(
        "SELECT dna_status FROM divisions WHERE division_id = ?1",
        [<<"div-1">>]),
    ?assertEqual(?PHASE_COMPLETED, DnaStatus).

%% ===================================================================
%% Roundtrip tests: project -> query via query desk modules
%% ===================================================================

roundtrip_by_id() ->
    ok = division_initiated_v1_to_sqlite_divisions:project(
        initiated_event(<<"div-1">>, <<"v-1">>)),
    {ok, Map} = get_division_by_id:get(<<"div-1">>),
    ?assertEqual(<<"div-1">>, maps:get(division_id, Map)),
    ?assertEqual(<<"v-1">>, maps:get(venture_id, Map)),
    ?assertEqual(<<"auth">>, maps:get(context_name, Map)),
    ?assertEqual(?DA_INITIATED, maps:get(overall_status, Map)),
    ?assertEqual(0, maps:get(dna_status, Map)),
    ?assertEqual(0, maps:get(anp_status, Map)),
    ?assertEqual(0, maps:get(tni_status, Map)),
    ?assertEqual(0, maps:get(dno_status, Map)),
    ?assertEqual(1000, maps:get(initiated_at, Map)),
    ?assertEqual(<<"user@test">>, maps:get(initiated_by, Map)).

roundtrip_page() ->
    ok = division_initiated_v1_to_sqlite_divisions:project(
        (initiated_event(<<"div-1">>, <<"v-1">>))#{initiated_at => 1000}),
    ok = division_initiated_v1_to_sqlite_divisions:project(
        (initiated_event(<<"div-2">>, <<"v-1">>))#{initiated_at => 2000}),
    {ok, Divs} = get_divisions_page:get(#{limit => 50, offset => 0}),
    ?assertEqual(2, length(Divs)),
    %% Ordered by initiated_at DESC
    [D1, D2] = Divs,
    ?assertEqual(<<"div-2">>, maps:get(division_id, D1)),
    ?assertEqual(<<"div-1">>, maps:get(division_id, D2)).

roundtrip_by_venture() ->
    ok = division_initiated_v1_to_sqlite_divisions:project(
        (initiated_event(<<"div-1">>, <<"v-1">>))#{initiated_at => 1000}),
    ok = division_initiated_v1_to_sqlite_divisions:project(
        (initiated_event(<<"div-2">>, <<"v-1">>))#{initiated_at => 2000}),
    ok = division_initiated_v1_to_sqlite_divisions:project(
        (initiated_event(<<"div-3">>, <<"v-2">>))#{initiated_at => 3000}),
    {ok, V1Divs} = get_divisions_by_venture:get(<<"v-1">>),
    ?assertEqual(2, length(V1Divs)),
    {ok, V2Divs} = get_divisions_by_venture:get(<<"v-2">>),
    ?assertEqual(1, length(V2Divs)).
