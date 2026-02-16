%%% @doc Tests for test_suite_run_v1 -> test_suites projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(test_suites_projection_tests).

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
            {"test_suite_run projects into test_suites", fun proj_test_suite_run/0},
            {"duplicate suite_id upserts row",            fun proj_upsert/0}
        ]
    }.

%% ===================================================================
%% Setup / Cleanup
%% ===================================================================

setup() ->
    file:delete(shared_paths:db_path("query_division_alc.db")),
    file:delete(shared_paths:db_path("query_division_alc.db-wal")),
    file:delete(shared_paths:db_path("query_division_alc.db-shm")),
    {ok, _} = application:ensure_all_started(esqlite),
    {ok, Pid} = query_division_alc_store:start_link(),
    Pid.

cleanup(Pid) ->
    gen_server:stop(Pid),
    file:delete(shared_paths:db_path("query_division_alc.db")),
    file:delete(shared_paths:db_path("query_division_alc.db-wal")),
    file:delete(shared_paths:db_path("query_division_alc.db-shm")),
    ok.

%% ===================================================================
%% Projection tests
%% ===================================================================

proj_test_suite_run() ->
    Event = #{
        division_id => <<"div-1">>,
        suite_id => <<"suite-1">>,
        suite_name => <<"unit_tests">>,
        run_at => 1000
    },
    ok = test_suite_run_v1_to_sqlite_test_suites:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT suite_id, division_id, suite_name FROM test_suites", []),
    ?assertEqual([[<<"suite-1">>, <<"div-1">>, <<"unit_tests">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        suite_id => <<"suite-1">>,
        suite_name => <<"unit_tests">>,
        run_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        suite_id => <<"suite-1">>,
        suite_name => <<"integration_tests">>,
        run_at => 2000
    },
    ok = test_suite_run_v1_to_sqlite_test_suites:project(Event1),
    ok = test_suite_run_v1_to_sqlite_test_suites:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT suite_name FROM test_suites WHERE suite_id = ?1",
        [<<"suite-1">>]),
    ?assertEqual([[<<"integration_tests">>]], Rows).
