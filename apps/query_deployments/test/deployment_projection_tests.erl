-module(deployment_projection_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("deploy_division/include/deployment_status.hrl").
projection_test_() ->
    {foreach, fun setup/0, fun teardown/1, [fun correct_flags/1, fun label_correct/1, fun archive_bits/1]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = deployments_test_store_proxy:start("/tmp/test_proj_deploys_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> deployments_test_store_proxy:stop(), ok.
correct_flags(#{}) -> fun() ->
    ok = deployment_started_v1_to_sqlite_deployments:project(#{<<"division_id">> => <<"d-sf">>, <<"started_at">> => 1000}),
    {ok, [{_, Status, _, _, _}]} = query_deployments_store:query(
        "SELECT division_id, status, status_label, started_at, started_by FROM deployments WHERE division_id = ?1", [<<"d-sf">>]),
    ?assertEqual(?DEPLOYMENT_INITIATED bor ?DEPLOYMENT_ACTIVE, Status) end.
label_correct(#{}) -> fun() ->
    ok = deployment_started_v1_to_sqlite_deployments:project(#{<<"division_id">> => <<"d-lb">>, <<"started_at">> => 1000}),
    {ok, [{Status, Label}]} = query_deployments_store:query("SELECT status, status_label FROM deployments WHERE division_id = ?1", [<<"d-lb">>]),
    ?assertEqual(evoq_bit_flags:to_string(Status, ?DEPLOYMENT_FLAG_MAP), Label) end.
archive_bits(#{}) -> fun() ->
    ok = deployment_started_v1_to_sqlite_deployments:project(#{<<"division_id">> => <<"d-ab">>, <<"started_at">> => 1000}),
    ok = deployment_archived_v1_to_sqlite_deployments:project(#{<<"division_id">> => <<"d-ab">>}),
    {ok, [{S}]} = query_deployments_store:query("SELECT status FROM deployments WHERE division_id = ?1", [<<"d-ab">>]),
    ?assertEqual(?DEPLOYMENT_INITIATED bor ?DEPLOYMENT_ACTIVE bor ?DEPLOYMENT_ARCHIVED, S) end.
