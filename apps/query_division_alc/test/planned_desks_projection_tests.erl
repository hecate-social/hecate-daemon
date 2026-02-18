%%% @doc Tests for desk_planned_v1 -> planned_desks projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(planned_desks_projection_tests).

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
            {"desk_planned projects into planned_desks", fun proj_desk_planned/0},
            {"duplicate desk_name upserts row",          fun proj_upsert/0}
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

proj_desk_planned() ->
    Event = #{
        division_id => <<"div-1">>,
        desk_name => <<"place_order">>,
        description => <<"Place order">>,
        department => <<"cmd">>,
        commands => [<<"place_order_v1">>],
        planned_at => 1000
    },
    ok = desk_planned_v1_to_sqlite_planned_desks:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT division_id, desk_name, department FROM planned_desks", []),
    ?assertEqual([[<<"div-1">>, <<"place_order">>, <<"cmd">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        desk_name => <<"place_order">>,
        description => <<"v1">>,
        department => <<"cmd">>,
        commands => [<<"place_order_v1">>],
        planned_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        desk_name => <<"place_order">>,
        description => <<"v2">>,
        department => <<"cmd">>,
        commands => [<<"place_order_v1">>, <<"cancel_order_v1">>],
        planned_at => 2000
    },
    ok = desk_planned_v1_to_sqlite_planned_desks:project(Event1),
    ok = desk_planned_v1_to_sqlite_planned_desks:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT description FROM planned_desks "
        "WHERE division_id = ?1 AND desk_name = ?2",
        [<<"div-1">>, <<"place_order">>]),
    ?assertEqual([[<<"v2">>]], Rows).
