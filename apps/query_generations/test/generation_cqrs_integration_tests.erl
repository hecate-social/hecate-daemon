-module(generation_cqrs_integration_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("generate_division/include/generation_status.hrl").

start_event(D) -> #{<<"division_id">> => D, <<"started_at">> => 1000, <<"started_by">> => <<"t">>}.
mod_event(D, M) -> #{<<"division_id">> => D, <<"module_id">> => M, <<"module_name">> => <<"user_handler">>, <<"module_type">> => <<"handler">>, <<"file_path">> => <<"/src/user_handler.erl">>, <<"content">> => <<"-module(user_handler).">>, <<"description">> => <<"Handler">>, <<"generated_by">> => <<"gen">>, <<"generated_at">> => 2000}.
test_event(D, T) -> #{<<"division_id">> => D, <<"test_id">> => T, <<"test_name">> => <<"user_handler_test">>, <<"test_type">> => <<"eunit">>, <<"module_name">> => <<"user_handler">>, <<"file_path">> => <<"/test/user_handler_tests.erl">>, <<"content">> => <<"-module(user_handler_tests).">>, <<"description">> => <<"Test">>, <<"generated_by">> => <<"gen">>, <<"generated_at">> => 3000}.
pause_event(D) -> #{<<"division_id">> => D, <<"paused_at">> => 4000, <<"reason">> => <<"review">>}.
complete_event(D) -> #{<<"division_id">> => D, <<"completed_at">> => 5000}.
archive_event(D) -> #{<<"division_id">> => D}.

cqrs_integration_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
      fun start_projects/1, fun query_found/1, fun query_not_found/1,
      fun pause_updates/1, fun complete_updates/1, fun archive_updates/1,
      fun mod_projects/1, fun test_projects/1, fun idempotency/1, fun full_flow/1
    ]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = generations_test_store_proxy:start("/tmp/test_gen_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> generations_test_store_proxy:stop(), ok.

start_projects(#{}) -> fun() -> ok = generation_started_v1_to_sqlite_generations:project(start_event(<<"d-1">>)),
    {ok, [{1}]} = query_generations_store:query("SELECT COUNT(*) FROM generations WHERE division_id = ?1", [<<"d-1">>]) end.
query_found(#{}) -> fun() -> ok = generation_started_v1_to_sqlite_generations:project(start_event(<<"d-q">>)),
    {ok, R} = get_generation_by_division_id:get(<<"d-q">>), ?assertEqual(<<"d-q">>, maps:get(division_id, R)),
    ?assertNotEqual(0, maps:get(status, R) band ?GENERATION_ACTIVE) end.
query_not_found(#{}) -> fun() -> ?assertEqual({error, not_found}, get_generation_by_division_id:get(<<"x">>)) end.
pause_updates(#{}) -> fun() -> ok = generation_started_v1_to_sqlite_generations:project(start_event(<<"d-p">>)),
    ok = generation_lifecycle_to_sqlite_generations:project_paused(pause_event(<<"d-p">>)),
    {ok, R} = get_generation_by_division_id:get(<<"d-p">>), ?assertNotEqual(0, maps:get(status, R) band ?GENERATION_PAUSED) end.
complete_updates(#{}) -> fun() -> ok = generation_started_v1_to_sqlite_generations:project(start_event(<<"d-c">>)),
    ok = generation_lifecycle_to_sqlite_generations:project_completed(complete_event(<<"d-c">>)),
    {ok, R} = get_generation_by_division_id:get(<<"d-c">>), ?assertNotEqual(0, maps:get(status, R) band ?GENERATION_COMPLETED) end.
archive_updates(#{}) -> fun() -> ok = generation_started_v1_to_sqlite_generations:project(start_event(<<"d-a">>)),
    ok = generation_archived_v1_to_sqlite_generations:project(archive_event(<<"d-a">>)),
    {ok, R} = get_generation_by_division_id:get(<<"d-a">>), ?assertNotEqual(0, maps:get(status, R) band ?GENERATION_ARCHIVED) end.
mod_projects(#{}) -> fun() -> ok = module_generated_v1_to_sqlite_generated_modules:project(mod_event(<<"d-m">>, <<"m-1">>)),
    {ok, [Row]} = get_generated_modules_page:get(#{division_id => <<"d-m">>}),
    ?assertEqual(<<"m-1">>, maps:get(module_id, Row)), ?assertEqual(<<"user_handler">>, maps:get(module_name, Row)) end.
test_projects(#{}) -> fun() -> ok = test_generated_v1_to_sqlite_generated_tests:project(test_event(<<"d-t">>, <<"t-1">>)),
    {ok, [Row]} = get_generated_tests_page:get(#{division_id => <<"d-t">>}),
    ?assertEqual(<<"t-1">>, maps:get(test_id, Row)) end.
idempotency(#{}) -> fun() -> E = start_event(<<"d-i">>), ok = generation_started_v1_to_sqlite_generations:project(E),
    ok = generation_started_v1_to_sqlite_generations:project(E),
    {ok, [{1}]} = query_generations_store:query("SELECT COUNT(*) FROM generations WHERE division_id = ?1", [<<"d-i">>]) end.
full_flow(#{}) -> fun() -> ok = generation_started_v1_to_sqlite_generations:project(start_event(<<"d-f">>)),
    ok = module_generated_v1_to_sqlite_generated_modules:project(mod_event(<<"d-f">>, <<"m-f">>)),
    ok = test_generated_v1_to_sqlite_generated_tests:project(test_event(<<"d-f">>, <<"t-f">>)),
    ok = generation_lifecycle_to_sqlite_generations:project_completed(complete_event(<<"d-f">>)),
    {ok, G} = get_generation_by_division_id:get(<<"d-f">>), ?assertNotEqual(0, maps:get(status, G) band ?GENERATION_COMPLETED),
    {ok, [_]} = get_generated_modules_page:get(#{division_id => <<"d-f">>}),
    {ok, [_]} = get_generated_tests_page:get(#{division_id => <<"d-f">>}) end.
