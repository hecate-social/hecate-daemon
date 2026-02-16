%%% @doc Tests for module_generated_v1 -> generated_modules projection.
%%%
%%% NOTE: esqlite3:fetchall returns rows as lists (not tuples):
%%%   Multi-column: [[col1, col2, ...], ...]
-module(generated_modules_projection_tests).

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
            {"module_generated projects into generated_modules", fun proj_module_generated/0},
            {"duplicate module_name upserts row",                 fun proj_upsert/0}
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

proj_module_generated() ->
    Event = #{
        division_id => <<"div-1">>,
        module_name => <<"place_order_v1">>,
        module_type => <<"command">>,
        path => <<"src/place_order_v1.erl">>,
        generated_at => 1000
    },
    ok = module_generated_v1_to_sqlite_generated_modules:project(Event),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT division_id, module_name, module_type FROM generated_modules", []),
    ?assertEqual([[<<"div-1">>, <<"place_order_v1">>, <<"command">>]], Rows).

proj_upsert() ->
    Event1 = #{
        division_id => <<"div-1">>,
        module_name => <<"place_order_v1">>,
        module_type => <<"command">>,
        path => <<"src/place_order_v1.erl">>,
        generated_at => 1000
    },
    Event2 = #{
        division_id => <<"div-1">>,
        module_name => <<"place_order_v1">>,
        module_type => <<"command">>,
        path => <<"src/place_order/place_order_v1.erl">>,
        generated_at => 2000
    },
    ok = module_generated_v1_to_sqlite_generated_modules:project(Event1),
    ok = module_generated_v1_to_sqlite_generated_modules:project(Event2),
    {ok, Rows} = query_division_alc_store:query(
        "SELECT path FROM generated_modules "
        "WHERE division_id = ?1 AND module_name = ?2",
        [<<"div-1">>, <<"place_order_v1">>]),
    ?assertEqual([[<<"src/place_order/place_order_v1.erl">>]], Rows).
