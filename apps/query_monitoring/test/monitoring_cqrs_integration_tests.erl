-module(monitoring_cqrs_integration_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("monitor_division/include/monitoring_status.hrl").

start_event(D) -> #{<<"division_id">> => D, <<"started_at">> => 1000, <<"started_by">> => <<"t">>}.
check_event(D, C) -> #{<<"check_id">> => C, <<"division_id">> => D, <<"check_name">> => <<"api_health">>, <<"check_type">> => <<"http">>, <<"endpoint">> => <<"https://api.example.com/health">>, <<"interval_ms">> => 30000, <<"registered_at">> => 2000}.
incident_event(D, I) -> #{<<"incident_id">> => I, <<"division_id">> => D, <<"incident_title">> => <<"API Down">>, <<"severity">> => <<"critical">>, <<"description">> => <<"500 errors">>, <<"raised_at">> => 3000}.
pause_event(D) -> #{<<"division_id">> => D, <<"paused_at">> => 4000, <<"reason">> => <<"maintenance">>}.
complete_event(D) -> #{<<"division_id">> => D, <<"completed_at">> => 5000}.
archive_event(D) -> #{<<"division_id">> => D}.

cqrs_integration_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
      fun start_projects/1, fun query_found/1, fun query_not_found/1,
      fun pause_updates/1, fun complete_updates/1, fun archive_updates/1,
      fun check_projects/1, fun incident_projects/1, fun idempotency/1, fun full_flow/1
    ]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = monitoring_test_store_proxy:start("/tmp/test_monitorings_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> monitoring_test_store_proxy:stop(), ok.

start_projects(#{}) -> fun() -> ok = monitoring_started_v1_to_sqlite_monitorings:project(start_event(<<"d-1">>)),
    {ok, [{1}]} = query_monitoring_store:query("SELECT COUNT(*) FROM monitorings WHERE division_id = ?1", [<<"d-1">>]) end.
query_found(#{}) -> fun() -> ok = monitoring_started_v1_to_sqlite_monitorings:project(start_event(<<"d-q">>)),
    {ok, R} = get_monitoring_by_division_id:get(<<"d-q">>), ?assertEqual(<<"d-q">>, maps:get(division_id, R)),
    ?assertNotEqual(0, maps:get(status, R) band ?MONITORING_ACTIVE) end.
query_not_found(#{}) -> fun() -> ?assertEqual({error, not_found}, get_monitoring_by_division_id:get(<<"x">>)) end.
pause_updates(#{}) -> fun() -> ok = monitoring_started_v1_to_sqlite_monitorings:project(start_event(<<"d-p">>)),
    ok = monitoring_lifecycle_to_sqlite_monitorings:project_paused(pause_event(<<"d-p">>)),
    {ok, R} = get_monitoring_by_division_id:get(<<"d-p">>), ?assertNotEqual(0, maps:get(status, R) band ?MONITORING_PAUSED) end.
complete_updates(#{}) -> fun() -> ok = monitoring_started_v1_to_sqlite_monitorings:project(start_event(<<"d-c">>)),
    ok = monitoring_lifecycle_to_sqlite_monitorings:project_completed(complete_event(<<"d-c">>)),
    {ok, R} = get_monitoring_by_division_id:get(<<"d-c">>), ?assertNotEqual(0, maps:get(status, R) band ?MONITORING_COMPLETED) end.
archive_updates(#{}) -> fun() -> ok = monitoring_started_v1_to_sqlite_monitorings:project(start_event(<<"d-a">>)),
    ok = monitoring_archived_v1_to_sqlite_monitorings:project(archive_event(<<"d-a">>)),
    {ok, R} = get_monitoring_by_division_id:get(<<"d-a">>), ?assertNotEqual(0, maps:get(status, R) band ?MONITORING_ARCHIVED) end.
check_projects(#{}) -> fun() -> ok = health_check_registered_v1_to_sqlite_health_checks:project(check_event(<<"d-h">>, <<"c-1">>)),
    {ok, [Row]} = get_health_checks_page:get(#{division_id => <<"d-h">>}),
    ?assertEqual(<<"c-1">>, maps:get(check_id, Row)), ?assertEqual(<<"api_health">>, maps:get(check_name, Row)) end.
incident_projects(#{}) -> fun() -> ok = incident_raised_v1_to_sqlite_incidents:project(incident_event(<<"d-i">>, <<"i-1">>)),
    {ok, [Row]} = get_incidents_page:get(#{division_id => <<"d-i">>}),
    ?assertEqual(<<"i-1">>, maps:get(incident_id, Row)), ?assertEqual(<<"critical">>, maps:get(severity, Row)) end.
idempotency(#{}) -> fun() -> E = start_event(<<"d-idem">>), ok = monitoring_started_v1_to_sqlite_monitorings:project(E),
    ok = monitoring_started_v1_to_sqlite_monitorings:project(E),
    {ok, [{1}]} = query_monitoring_store:query("SELECT COUNT(*) FROM monitorings WHERE division_id = ?1", [<<"d-idem">>]) end.
full_flow(#{}) -> fun() -> ok = monitoring_started_v1_to_sqlite_monitorings:project(start_event(<<"d-f">>)),
    ok = health_check_registered_v1_to_sqlite_health_checks:project(check_event(<<"d-f">>, <<"c-f">>)),
    ok = incident_raised_v1_to_sqlite_incidents:project(incident_event(<<"d-f">>, <<"i-f">>)),
    ok = monitoring_lifecycle_to_sqlite_monitorings:project_completed(complete_event(<<"d-f">>)),
    {ok, M} = get_monitoring_by_division_id:get(<<"d-f">>), ?assertNotEqual(0, maps:get(status, M) band ?MONITORING_COMPLETED) end.
