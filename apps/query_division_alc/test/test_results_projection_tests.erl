%%% @doc Tests for test_result_recorded_v1 -> test_results projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(test_results_projection_tests).

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
            {"test_result_recorded projects into test_results", fun proj_test_result_recorded/0},
            {"duplicate result_id upserts row",                  fun proj_upsert/0}
        ]
    }.

%% ===================================================================
%% Setup / Cleanup
%% ===================================================================

setup() ->
    ok = filelib:ensure_dir("data/dummy"),
    file:delete("data/query_division_alc.db"),
    file:delete("data/query_division_alc.db-wal"),
    file:delete("data/query_division_alc.db-shm"),
    {ok, _} = application:ensure_all_started(esqlite),
    {ok, Pid} = query_division_alc_store:start_link(),
    Pid.

cleanup(Pid) ->
    gen_server:stop(Pid),
    file:delete("data/query_division_alc.db"),
    file:delete("data/query_division_alc.db-wal"),
    file:delete("data/query_division_alc.db-shm"),
    ok.

%% ===================================================================
%% Projection tests
%% ===================================================================

proj_test_result_recorded() ->
    Event = #{
        division_id => <<"div-1">>,
        result_id => <<"res-1">>,
        suite_id => <<"suite-1">>,
        passed => 10,
        failed => 2,
        recorded_at => 1000
    },
    ok = test_result_recorded_v1_to_sqlite_test_results:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT result_id, division_id, suite_id, passed, failed "
        "FROM test_results", []),
    ?assertEqual([[<<"res-1">>, <<"div-1">>, <<"suite-1">>, 10, 2]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        result_id => <<"res-1">>,
        suite_id => <<"suite-1">>,
        passed => 10,
        failed => 2,
        recorded_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        result_id => <<"res-1">>,
        suite_id => <<"suite-1">>,
        passed => 12,
        failed => 0,
        recorded_at => 2000
    },
    ok = test_result_recorded_v1_to_sqlite_test_results:project(Event1),
    ok = test_result_recorded_v1_to_sqlite_test_results:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT passed, failed FROM test_results WHERE result_id = ?1",
        [<<"res-1">>]),
    ?assertEqual([[12, 0]], Rows).
