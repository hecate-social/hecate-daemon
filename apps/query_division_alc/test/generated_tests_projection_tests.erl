%%% @doc Tests for test_generated_v1 -> generated_tests projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(generated_tests_projection_tests).

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
            {"test_generated projects into generated_tests", fun proj_test_generated/0},
            {"duplicate test_name upserts row",               fun proj_upsert/0}
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

proj_test_generated() ->
    Event = #{
        division_id => <<"div-1">>,
        test_name => <<"order_tests">>,
        module_name => <<"order">>,
        path => <<"test/order_tests.erl">>,
        generated_at => 1000
    },
    ok = test_generated_v1_to_sqlite_generated_tests:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT division_id, test_name, module_name FROM generated_tests", []),
    ?assertEqual([[<<"div-1">>, <<"order_tests">>, <<"order">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        test_name => <<"order_tests">>,
        module_name => <<"order">>,
        path => <<"test/order_tests.erl">>,
        generated_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        test_name => <<"order_tests">>,
        module_name => <<"order_v2">>,
        path => <<"test/order_v2_tests.erl">>,
        generated_at => 2000
    },
    ok = test_generated_v1_to_sqlite_generated_tests:project(Event1),
    ok = test_generated_v1_to_sqlite_generated_tests:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT module_name FROM generated_tests "
        "WHERE division_id = ?1 AND test_name = ?2",
        [<<"div-1">>, <<"order_tests">>]),
    ?assertEqual([[<<"order_v2">>]], Rows).
