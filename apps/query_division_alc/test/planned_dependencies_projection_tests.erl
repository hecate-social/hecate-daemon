%%% @doc Tests for dependency_planned_v1 -> planned_dependencies projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(planned_dependencies_projection_tests).

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
            {"dependency_planned projects into planned_dependencies", fun proj_dependency_planned/0},
            {"duplicate dependency_id upserts row",                   fun proj_upsert/0}
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

proj_dependency_planned() ->
    Event = #{
        division_id => <<"div-1">>,
        dependency_id => <<"dep-1">>,
        from_desk => <<"place_order">>,
        to_desk => <<"notify">>,
        dep_type => <<"event">>,
        planned_at => 1000
    },
    ok = dependency_planned_v1_to_sqlite_planned_dependencies:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT division_id, dependency_id, from_desk, to_desk "
        "FROM planned_dependencies", []),
    ?assertEqual([[<<"div-1">>, <<"dep-1">>, <<"place_order">>, <<"notify">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        dependency_id => <<"dep-1">>,
        from_desk => <<"place_order">>,
        to_desk => <<"notify">>,
        dep_type => <<"event">>,
        planned_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        dependency_id => <<"dep-1">>,
        from_desk => <<"place_order">>,
        to_desk => <<"ship">>,
        dep_type => <<"command">>,
        planned_at => 2000
    },
    ok = dependency_planned_v1_to_sqlite_planned_dependencies:project(Event1),
    ok = dependency_planned_v1_to_sqlite_planned_dependencies:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT to_desk, dep_type FROM planned_dependencies "
        "WHERE division_id = ?1 AND dependency_id = ?2",
        [<<"div-1">>, <<"dep-1">>]),
    ?assertEqual([[<<"ship">>, <<"command">>]], Rows).
