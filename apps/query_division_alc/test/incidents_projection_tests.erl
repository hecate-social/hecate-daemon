%%% @doc Tests for incident_raised_v1 -> incidents projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(incidents_projection_tests).

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
            {"incident_raised projects into incidents", fun proj_incident_raised/0},
            {"duplicate incident_id upserts row",       fun proj_upsert/0}
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

proj_incident_raised() ->
    Event = #{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        title => <<"API down">>,
        severity => <<"critical">>,
        raised_at => 1000
    },
    ok = incident_raised_v1_to_sqlite_incidents:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT incident_id, division_id, title, severity FROM incidents", []),
    ?assertEqual([[<<"inc-1">>, <<"div-1">>, <<"API down">>, <<"critical">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        title => <<"API down">>,
        severity => <<"critical">>,
        raised_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        title => <<"API down (updated)">>,
        severity => <<"high">>,
        raised_at => 2000
    },
    ok = incident_raised_v1_to_sqlite_incidents:project(Event1),
    ok = incident_raised_v1_to_sqlite_incidents:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT title, severity FROM incidents WHERE incident_id = ?1",
        [<<"inc-1">>]),
    ?assertEqual([[<<"API down (updated)">>, <<"high">>]], Rows).
