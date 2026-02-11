-module(rescue_projection_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("rescue_division/include/rescue_status.hrl").
projection_test_() ->
    {foreach, fun setup/0, fun teardown/1, [fun correct_flags/1, fun label_correct/1, fun archive_bits/1]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = rescues_test_store_proxy:start("/tmp/test_proj_rescues_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> rescues_test_store_proxy:stop(), ok.
correct_flags(#{}) -> fun() ->
    ok = rescue_started_v1_to_sqlite_rescues:project(#{<<"division_id">> => <<"d-sf">>, <<"incident_id">> => <<"inc-1">>, <<"started_at">> => 1000}),
    {ok, [{_, _, Status, _, _, _}]} = query_rescues_store:query(
        "SELECT division_id, incident_id, status, status_label, started_at, started_by FROM rescues WHERE division_id = ?1", [<<"d-sf">>]),
    ?assertEqual(?RESCUE_INITIATED bor ?RESCUE_ACTIVE, Status) end.
label_correct(#{}) -> fun() ->
    ok = rescue_started_v1_to_sqlite_rescues:project(#{<<"division_id">> => <<"d-lb">>, <<"incident_id">> => <<"inc-1">>, <<"started_at">> => 1000}),
    {ok, [{Status, Label}]} = query_rescues_store:query("SELECT status, status_label FROM rescues WHERE division_id = ?1", [<<"d-lb">>]),
    ?assertEqual(evoq_bit_flags:to_string(Status, ?RESCUE_FLAG_MAP), Label) end.
archive_bits(#{}) -> fun() ->
    ok = rescue_started_v1_to_sqlite_rescues:project(#{<<"division_id">> => <<"d-ab">>, <<"incident_id">> => <<"inc-1">>, <<"started_at">> => 1000}),
    ok = rescue_archived_v1_to_sqlite_rescues:project(#{<<"division_id">> => <<"d-ab">>}),
    {ok, [{S}]} = query_rescues_store:query("SELECT status FROM rescues WHERE division_id = ?1", [<<"d-ab">>]),
    ?assertEqual(?RESCUE_INITIATED bor ?RESCUE_ACTIVE bor ?RESCUE_ARCHIVED, S) end.
