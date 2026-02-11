-module(testing_cqrs_integration_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("test_division/include/testing_status.hrl").

start_event(D) -> #{<<"division_id">> => D, <<"started_at">> => 1000, <<"started_by">> => <<"t">>}.
suite_event(D, S) -> #{<<"division_id">> => D, <<"suite_id">> => S, <<"suite_name">> => <<"user_tests">>, <<"suite_type">> => <<"eunit">>, <<"target_module">> => <<"user_handler">>, <<"run_at">> => 2000}.
result_event(D, R) -> #{<<"division_id">> => D, <<"result_id">> => R, <<"suite_id">> => <<"s-1">>, <<"test_name">> => <<"register_test">>, <<"status">> => <<"passed">>, <<"details">> => <<"ok">>, <<"recorded_at">> => 3000}.
pause_event(D) -> #{<<"division_id">> => D, <<"paused_at">> => 4000, <<"reason">> => <<"review">>}.
complete_event(D) -> #{<<"division_id">> => D, <<"completed_at">> => 5000}.
archive_event(D) -> #{<<"division_id">> => D}.

cqrs_integration_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
      fun start_projects/1, fun query_found/1, fun query_not_found/1,
      fun pause_updates/1, fun complete_updates/1, fun archive_updates/1,
      fun suite_projects/1, fun result_projects/1, fun idempotency/1, fun full_flow/1
    ]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = testings_test_store_proxy:start("/tmp/test_testings_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> testings_test_store_proxy:stop(), ok.

start_projects(#{}) -> fun() -> ok = testing_started_v1_to_sqlite_testings:project(start_event(<<"d-1">>)),
    {ok, [{1}]} = query_tests_store:query("SELECT COUNT(*) FROM testings WHERE division_id = ?1", [<<"d-1">>]) end.
query_found(#{}) -> fun() -> ok = testing_started_v1_to_sqlite_testings:project(start_event(<<"d-q">>)),
    {ok, R} = get_testing_by_division_id:get(<<"d-q">>), ?assertEqual(<<"d-q">>, maps:get(division_id, R)),
    ?assertNotEqual(0, maps:get(status, R) band ?TESTING_ACTIVE) end.
query_not_found(#{}) -> fun() -> ?assertEqual({error, not_found}, get_testing_by_division_id:get(<<"x">>)) end.
pause_updates(#{}) -> fun() -> ok = testing_started_v1_to_sqlite_testings:project(start_event(<<"d-p">>)),
    ok = testing_lifecycle_to_sqlite_testings:project_paused(pause_event(<<"d-p">>)),
    {ok, R} = get_testing_by_division_id:get(<<"d-p">>), ?assertNotEqual(0, maps:get(status, R) band ?TESTING_PAUSED) end.
complete_updates(#{}) -> fun() -> ok = testing_started_v1_to_sqlite_testings:project(start_event(<<"d-c">>)),
    ok = testing_lifecycle_to_sqlite_testings:project_completed(complete_event(<<"d-c">>)),
    {ok, R} = get_testing_by_division_id:get(<<"d-c">>), ?assertNotEqual(0, maps:get(status, R) band ?TESTING_COMPLETED) end.
archive_updates(#{}) -> fun() -> ok = testing_started_v1_to_sqlite_testings:project(start_event(<<"d-a">>)),
    ok = testing_archived_v1_to_sqlite_testings:project(archive_event(<<"d-a">>)),
    {ok, R} = get_testing_by_division_id:get(<<"d-a">>), ?assertNotEqual(0, maps:get(status, R) band ?TESTING_ARCHIVED) end.
suite_projects(#{}) -> fun() -> ok = test_suite_run_v1_to_sqlite_test_suites:project(suite_event(<<"d-s">>, <<"s-1">>)),
    {ok, [Row]} = get_test_suites_page:get(#{division_id => <<"d-s">>}),
    ?assertEqual(<<"s-1">>, maps:get(suite_id, Row)), ?assertEqual(<<"user_tests">>, maps:get(suite_name, Row)) end.
result_projects(#{}) -> fun() -> ok = test_result_recorded_v1_to_sqlite_test_results:project(result_event(<<"d-r">>, <<"r-1">>)),
    {ok, [Row]} = get_test_results_page:get(#{division_id => <<"d-r">>}),
    ?assertEqual(<<"r-1">>, maps:get(result_id, Row)), ?assertEqual(<<"passed">>, maps:get(status, Row)) end.
idempotency(#{}) -> fun() -> E = start_event(<<"d-i">>), ok = testing_started_v1_to_sqlite_testings:project(E),
    ok = testing_started_v1_to_sqlite_testings:project(E),
    {ok, [{1}]} = query_tests_store:query("SELECT COUNT(*) FROM testings WHERE division_id = ?1", [<<"d-i">>]) end.
full_flow(#{}) -> fun() -> ok = testing_started_v1_to_sqlite_testings:project(start_event(<<"d-f">>)),
    ok = test_suite_run_v1_to_sqlite_test_suites:project(suite_event(<<"d-f">>, <<"s-f">>)),
    ok = test_result_recorded_v1_to_sqlite_test_results:project(result_event(<<"d-f">>, <<"r-f">>)),
    ok = testing_lifecycle_to_sqlite_testings:project_completed(complete_event(<<"d-f">>)),
    {ok, T} = get_testing_by_division_id:get(<<"d-f">>), ?assertNotEqual(0, maps:get(status, T) band ?TESTING_COMPLETED) end.
