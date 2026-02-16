%%% @doc Tests for event_designed_v1 -> designed_events projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(designed_events_projection_tests).

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
            {"event_designed projects into designed_events", fun proj_event_designed/0},
            {"duplicate event_name upserts row",             fun proj_upsert/0}
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

proj_event_designed() ->
    Event = #{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>,
        description => <<"Placed">>,
        aggregate_name => <<"order">>,
        fields => [<<"order_id">>],
        designed_at => 1000
    },
    ok = event_designed_v1_to_sqlite_designed_events:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT division_id, event_name, aggregate_name FROM designed_events", []),
    ?assertEqual([[<<"div-1">>, <<"order_placed_v1">>, <<"order">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>,
        description => <<"v1">>,
        aggregate_name => <<"order">>,
        fields => [<<"order_id">>],
        designed_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>,
        description => <<"v2">>,
        aggregate_name => <<"order">>,
        fields => [<<"order_id">>, <<"amount">>],
        designed_at => 2000
    },
    ok = event_designed_v1_to_sqlite_designed_events:project(Event1),
    ok = event_designed_v1_to_sqlite_designed_events:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT description FROM designed_events "
        "WHERE division_id = ?1 AND event_name = ?2",
        [<<"div-1">>, <<"order_placed_v1">>]),
    ?assertEqual([[<<"v2">>]], Rows).
