%%% @doc Tests for incident_diagnosed_v1 -> diagnoses projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(diagnoses_projection_tests).

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
            {"incident_diagnosed projects into diagnoses", fun proj_incident_diagnosed/0},
            {"duplicate diagnosis_id upserts row",          fun proj_upsert/0}
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

proj_incident_diagnosed() ->
    Event = #{
        division_id => <<"div-1">>,
        diagnosis_id => <<"diag-1">>,
        incident_id => <<"inc-1">>,
        root_cause => <<"OOM">>,
        diagnosed_at => 1000
    },
    ok = incident_diagnosed_v1_to_sqlite_diagnoses:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT diagnosis_id, division_id, incident_id, root_cause "
        "FROM diagnoses", []),
    ?assertEqual([[<<"diag-1">>, <<"div-1">>, <<"inc-1">>, <<"OOM">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        diagnosis_id => <<"diag-1">>,
        incident_id => <<"inc-1">>,
        root_cause => <<"OOM">>,
        diagnosed_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        diagnosis_id => <<"diag-1">>,
        incident_id => <<"inc-1">>,
        root_cause => <<"Memory leak in worker pool">>,
        diagnosed_at => 2000
    },
    ok = incident_diagnosed_v1_to_sqlite_diagnoses:project(Event1),
    ok = incident_diagnosed_v1_to_sqlite_diagnoses:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT root_cause FROM diagnoses WHERE diagnosis_id = ?1",
        [<<"diag-1">>]),
    ?assertEqual([[<<"Memory leak in worker pool">>]], Rows).
