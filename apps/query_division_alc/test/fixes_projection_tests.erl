%%% @doc Tests for fix_applied_v1 -> fixes projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(fixes_projection_tests).

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
            {"fix_applied projects into fixes", fun proj_fix_applied/0},
            {"duplicate fix_id upserts row",     fun proj_upsert/0}
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

proj_fix_applied() ->
    Event = #{
        division_id => <<"div-1">>,
        fix_id => <<"fix-1">>,
        incident_id => <<"inc-1">>,
        description => <<"Bumped memory">>,
        applied_at => 1000
    },
    ok = fix_applied_v1_to_sqlite_fixes:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT fix_id, division_id, incident_id, description FROM fixes", []),
    ?assertEqual([[<<"fix-1">>, <<"div-1">>, <<"inc-1">>, <<"Bumped memory">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        fix_id => <<"fix-1">>,
        incident_id => <<"inc-1">>,
        description => <<"Bumped memory">>,
        applied_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        fix_id => <<"fix-1">>,
        incident_id => <<"inc-1">>,
        description => <<"Bumped memory + added swap">>,
        applied_at => 2000
    },
    ok = fix_applied_v1_to_sqlite_fixes:project(Event1),
    ok = fix_applied_v1_to_sqlite_fixes:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT description FROM fixes WHERE fix_id = ?1",
        [<<"fix-1">>]),
    ?assertEqual([[<<"Bumped memory + added swap">>]], Rows).
