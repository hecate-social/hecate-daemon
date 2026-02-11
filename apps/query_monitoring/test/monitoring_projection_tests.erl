-module(monitoring_projection_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("monitor_division/include/monitoring_status.hrl").
projection_test_() ->
    {foreach, fun setup/0, fun teardown/1, [fun correct_flags/1, fun label_correct/1, fun archive_bits/1]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = monitoring_test_store_proxy:start("/tmp/test_proj_monitorings_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> monitoring_test_store_proxy:stop(), ok.
correct_flags(#{}) -> fun() ->
    ok = monitoring_started_v1_to_sqlite_monitorings:project(#{<<"division_id">> => <<"d-sf">>, <<"started_at">> => 1000}),
    {ok, [{_, Status, _, _, _}]} = query_monitoring_store:query(
        "SELECT division_id, status, status_label, started_at, started_by FROM monitorings WHERE division_id = ?1", [<<"d-sf">>]),
    ?assertEqual(?MONITORING_INITIATED bor ?MONITORING_ACTIVE, Status) end.
label_correct(#{}) -> fun() ->
    ok = monitoring_started_v1_to_sqlite_monitorings:project(#{<<"division_id">> => <<"d-lb">>, <<"started_at">> => 1000}),
    {ok, [{Status, Label}]} = query_monitoring_store:query("SELECT status, status_label FROM monitorings WHERE division_id = ?1", [<<"d-lb">>]),
    ?assertEqual(evoq_bit_flags:to_string(Status, ?MONITORING_FLAG_MAP), Label) end.
archive_bits(#{}) -> fun() ->
    ok = monitoring_started_v1_to_sqlite_monitorings:project(#{<<"division_id">> => <<"d-ab">>, <<"started_at">> => 1000}),
    ok = monitoring_archived_v1_to_sqlite_monitorings:project(#{<<"division_id">> => <<"d-ab">>}),
    {ok, [{S}]} = query_monitoring_store:query("SELECT status FROM monitorings WHERE division_id = ?1", [<<"d-ab">>]),
    ?assertEqual(?MONITORING_INITIATED bor ?MONITORING_ACTIVE bor ?MONITORING_ARCHIVED, S) end.
