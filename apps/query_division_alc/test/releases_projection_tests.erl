%%% @doc Tests for release_deployed_v1 -> releases projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(releases_projection_tests).

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
            {"release_deployed projects into releases", fun proj_release_deployed/0},
            {"duplicate release_id upserts row",         fun proj_upsert/0}
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
%% Projection tests
%% ===================================================================

proj_release_deployed() ->
    Event = #{
        division_id => <<"div-1">>,
        release_id => <<"rel-1">>,
        version => <<"0.1.0">>,
        deployed_at => 1000
    },
    ok = release_deployed_v1_to_sqlite_releases:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT release_id, division_id, version FROM releases", []),
    ?assertEqual([[<<"rel-1">>, <<"div-1">>, <<"0.1.0">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        release_id => <<"rel-1">>,
        version => <<"0.1.0">>,
        deployed_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        release_id => <<"rel-1">>,
        version => <<"0.2.0">>,
        deployed_at => 2000
    },
    ok = release_deployed_v1_to_sqlite_releases:project(Event1),
    ok = release_deployed_v1_to_sqlite_releases:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT version FROM releases WHERE release_id = ?1",
        [<<"rel-1">>]),
    ?assertEqual([[<<"0.2.0">>]], Rows).
