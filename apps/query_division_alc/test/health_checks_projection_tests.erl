%%% @doc Tests for health_check_registered_v1 -> health_checks projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(health_checks_projection_tests).

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
            {"health_check_registered projects into health_checks", fun proj_health_check_registered/0},
            {"duplicate check_id upserts row",                       fun proj_upsert/0}
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

proj_health_check_registered() ->
    Event = #{
        division_id => <<"div-1">>,
        check_id => <<"chk-1">>,
        check_name => <<"api_health">>,
        check_type => <<"http">>,
        registered_at => 1000
    },
    ok = health_check_registered_v1_to_sqlite_health_checks:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT check_id, division_id, check_name, check_type "
        "FROM health_checks", []),
    ?assertEqual([[<<"chk-1">>, <<"div-1">>, <<"api_health">>, <<"http">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        check_id => <<"chk-1">>,
        check_name => <<"api_health">>,
        check_type => <<"http">>,
        registered_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        check_id => <<"chk-1">>,
        check_name => <<"api_health_v2">>,
        check_type => <<"grpc">>,
        registered_at => 2000
    },
    ok = health_check_registered_v1_to_sqlite_health_checks:project(Event1),
    ok = health_check_registered_v1_to_sqlite_health_checks:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT check_name, check_type FROM health_checks WHERE check_id = ?1",
        [<<"chk-1">>]),
    ?assertEqual([[<<"api_health_v2">>, <<"grpc">>]], Rows).
