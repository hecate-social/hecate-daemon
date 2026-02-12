%%% @doc Tests for aggregate_designed_v1 -> designed_aggregates projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(designed_aggregates_projection_tests).

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
            {"aggregate_designed projects into designed_aggregates", fun proj_aggregate_designed/0},
            {"duplicate aggregate_name upserts row",                fun proj_upsert/0}
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

proj_aggregate_designed() ->
    Event = #{
        division_id => <<"div-1">>,
        aggregate_name => <<"order">>,
        description => <<"Order agg">>,
        stream_prefix => <<"order-">>,
        fields => [<<"id">>],
        designed_at => 1000
    },
    ok = aggregate_designed_v1_to_sqlite_designed_aggregates:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT division_id, aggregate_name, description FROM designed_aggregates", []),
    ?assertEqual([[<<"div-1">>, <<"order">>, <<"Order agg">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        aggregate_name => <<"order">>,
        description => <<"v1">>,
        stream_prefix => <<"order-">>,
        fields => [<<"id">>],
        designed_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        aggregate_name => <<"order">>,
        description => <<"v2">>,
        stream_prefix => <<"order-">>,
        fields => [<<"id">>, <<"status">>],
        designed_at => 2000
    },
    ok = aggregate_designed_v1_to_sqlite_designed_aggregates:project(Event1),
    ok = aggregate_designed_v1_to_sqlite_designed_aggregates:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT description FROM designed_aggregates "
        "WHERE division_id = ?1 AND aggregate_name = ?2",
        [<<"div-1">>, <<"order">>]),
    ?assertEqual([[<<"v2">>]], Rows).
