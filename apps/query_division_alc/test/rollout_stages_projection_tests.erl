%%% @doc Tests for rollout_staged_v1 -> rollout_stages projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(rollout_stages_projection_tests).

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
            {"rollout_staged projects into rollout_stages", fun proj_rollout_staged/0},
            {"duplicate stage_id upserts row",               fun proj_upsert/0}
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

proj_rollout_staged() ->
    Event = #{
        division_id => <<"div-1">>,
        stage_id => <<"stg-1">>,
        release_id => <<"rel-1">>,
        stage_name => <<"canary">>,
        staged_at => 1000
    },
    ok = rollout_staged_v1_to_sqlite_rollout_stages:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT stage_id, division_id, release_id, stage_name "
        "FROM rollout_stages", []),
    ?assertEqual([[<<"stg-1">>, <<"div-1">>, <<"rel-1">>, <<"canary">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        stage_id => <<"stg-1">>,
        release_id => <<"rel-1">>,
        stage_name => <<"canary">>,
        staged_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        stage_id => <<"stg-1">>,
        release_id => <<"rel-1">>,
        stage_name => <<"production">>,
        staged_at => 2000
    },
    ok = rollout_staged_v1_to_sqlite_rollout_stages:project(Event1),
    ok = rollout_staged_v1_to_sqlite_rollout_stages:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT stage_name FROM rollout_stages WHERE stage_id = ?1",
        [<<"stg-1">>]),
    ?assertEqual([[<<"production">>]], Rows).
