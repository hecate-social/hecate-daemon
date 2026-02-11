-module(testing_projection_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("test_division/include/testing_status.hrl").
projection_test_() ->
    {foreach, fun setup/0, fun teardown/1, [fun correct_flags/1, fun label_correct/1, fun archive_bits/1]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = testings_test_store_proxy:start("/tmp/test_proj_testings_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> testings_test_store_proxy:stop(), ok.
correct_flags(#{}) -> fun() ->
    ok = testing_started_v1_to_sqlite_testings:project(#{<<"division_id">> => <<"d-sf">>, <<"started_at">> => 1000}),
    {ok, [{_, Status, _, _, _}]} = query_tests_store:query(
        "SELECT division_id, status, status_label, started_at, started_by FROM testings WHERE division_id = ?1", [<<"d-sf">>]),
    ?assertEqual(?TESTING_INITIATED bor ?TESTING_ACTIVE, Status) end.
label_correct(#{}) -> fun() ->
    ok = testing_started_v1_to_sqlite_testings:project(#{<<"division_id">> => <<"d-lb">>, <<"started_at">> => 1000}),
    {ok, [{Status, Label}]} = query_tests_store:query("SELECT status, status_label FROM testings WHERE division_id = ?1", [<<"d-lb">>]),
    ?assertEqual(evoq_bit_flags:to_string(Status, ?TESTING_FLAG_MAP), Label) end.
archive_bits(#{}) -> fun() ->
    ok = testing_started_v1_to_sqlite_testings:project(#{<<"division_id">> => <<"d-ab">>, <<"started_at">> => 1000}),
    ok = testing_archived_v1_to_sqlite_testings:project(#{<<"division_id">> => <<"d-ab">>}),
    {ok, [{S}]} = query_tests_store:query("SELECT status FROM testings WHERE division_id = ?1", [<<"d-ab">>]),
    ?assertEqual(?TESTING_INITIATED bor ?TESTING_ACTIVE bor ?TESTING_ARCHIVED, S) end.
