-module(rescue_cqrs_integration_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("rescue_division/include/rescue_status.hrl").

start_event(D) -> #{<<"division_id">> => D, <<"incident_id">> => <<"inc-1">>, <<"started_at">> => 1000, <<"started_by">> => <<"t">>}.
diagnosis_event(D, Diag) -> #{<<"diagnosis_id">> => Diag, <<"division_id">> => D, <<"incident_id">> => <<"inc-1">>, <<"diagnosis">> => <<"memory leak">>, <<"root_cause">> => <<"unbounded cache">>, <<"diagnosed_by">> => <<"eng">>, <<"diagnosed_at">> => 2000}.
fix_event(D, F) -> #{<<"fix_id">> => F, <<"division_id">> => D, <<"incident_id">> => <<"inc-1">>, <<"diagnosis_id">> => <<"diag-1">>, <<"fix_description">> => <<"add LRU eviction">>, <<"fix_type">> => <<"code_change">>, <<"applied_by">> => <<"eng">>, <<"applied_at">> => 3000}.
pause_event(D) -> #{<<"division_id">> => D, <<"paused_at">> => 4000, <<"reason">> => <<"awaiting review">>}.
complete_event(D) -> #{<<"division_id">> => D, <<"completed_at">> => 5000}.
archive_event(D) -> #{<<"division_id">> => D}.

cqrs_integration_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
      fun start_projects/1, fun query_found/1, fun query_not_found/1,
      fun pause_updates/1, fun complete_updates/1, fun archive_updates/1,
      fun diagnosis_projects/1, fun fix_projects/1, fun idempotency/1, fun full_flow/1
    ]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = rescues_test_store_proxy:start("/tmp/test_rescues_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> rescues_test_store_proxy:stop(), ok.

start_projects(#{}) -> fun() -> ok = rescue_started_v1_to_sqlite_rescues:project(start_event(<<"d-1">>)),
    {ok, [{1}]} = query_rescues_store:query("SELECT COUNT(*) FROM rescues WHERE division_id = ?1", [<<"d-1">>]) end.
query_found(#{}) -> fun() -> ok = rescue_started_v1_to_sqlite_rescues:project(start_event(<<"d-q">>)),
    {ok, R} = get_rescue_by_division_id:get(<<"d-q">>), ?assertEqual(<<"d-q">>, maps:get(division_id, R)),
    ?assertNotEqual(0, maps:get(status, R) band ?RESCUE_ACTIVE) end.
query_not_found(#{}) -> fun() -> ?assertEqual({error, not_found}, get_rescue_by_division_id:get(<<"x">>)) end.
pause_updates(#{}) -> fun() -> ok = rescue_started_v1_to_sqlite_rescues:project(start_event(<<"d-p">>)),
    ok = rescue_lifecycle_to_sqlite_rescues:project_paused(pause_event(<<"d-p">>)),
    {ok, R} = get_rescue_by_division_id:get(<<"d-p">>), ?assertNotEqual(0, maps:get(status, R) band ?RESCUE_PAUSED) end.
complete_updates(#{}) -> fun() -> ok = rescue_started_v1_to_sqlite_rescues:project(start_event(<<"d-c">>)),
    ok = rescue_lifecycle_to_sqlite_rescues:project_completed(complete_event(<<"d-c">>)),
    {ok, R} = get_rescue_by_division_id:get(<<"d-c">>), ?assertNotEqual(0, maps:get(status, R) band ?RESCUE_COMPLETED) end.
archive_updates(#{}) -> fun() -> ok = rescue_started_v1_to_sqlite_rescues:project(start_event(<<"d-a">>)),
    ok = rescue_archived_v1_to_sqlite_rescues:project(archive_event(<<"d-a">>)),
    {ok, R} = get_rescue_by_division_id:get(<<"d-a">>), ?assertNotEqual(0, maps:get(status, R) band ?RESCUE_ARCHIVED) end.
diagnosis_projects(#{}) -> fun() -> ok = incident_diagnosed_v1_to_sqlite_diagnoses:project(diagnosis_event(<<"d-d">>, <<"diag-1">>)),
    {ok, [Row]} = get_diagnoses_page:get(#{division_id => <<"d-d">>}),
    ?assertEqual(<<"diag-1">>, maps:get(diagnosis_id, Row)), ?assertEqual(<<"unbounded cache">>, maps:get(root_cause, Row)) end.
fix_projects(#{}) -> fun() -> ok = fix_applied_v1_to_sqlite_fixes:project(fix_event(<<"d-x">>, <<"f-1">>)),
    {ok, [Row]} = get_fixes_page:get(#{division_id => <<"d-x">>}),
    ?assertEqual(<<"f-1">>, maps:get(fix_id, Row)), ?assertEqual(<<"code_change">>, maps:get(fix_type, Row)) end.
idempotency(#{}) -> fun() -> E = start_event(<<"d-i">>), ok = rescue_started_v1_to_sqlite_rescues:project(E),
    ok = rescue_started_v1_to_sqlite_rescues:project(E),
    {ok, [{1}]} = query_rescues_store:query("SELECT COUNT(*) FROM rescues WHERE division_id = ?1", [<<"d-i">>]) end.
full_flow(#{}) -> fun() -> ok = rescue_started_v1_to_sqlite_rescues:project(start_event(<<"d-f">>)),
    ok = incident_diagnosed_v1_to_sqlite_diagnoses:project(diagnosis_event(<<"d-f">>, <<"diag-f">>)),
    ok = fix_applied_v1_to_sqlite_fixes:project(fix_event(<<"d-f">>, <<"f-f">>)),
    ok = rescue_lifecycle_to_sqlite_rescues:project_completed(complete_event(<<"d-f">>)),
    {ok, R} = get_rescue_by_division_id:get(<<"d-f">>), ?assertNotEqual(0, maps:get(status, R) band ?RESCUE_COMPLETED) end.
