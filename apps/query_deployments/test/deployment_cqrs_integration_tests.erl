-module(deployment_cqrs_integration_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("deploy_division/include/deployment_status.hrl").

start_event(D) -> #{<<"division_id">> => D, <<"started_at">> => 1000, <<"started_by">> => <<"t">>}.
release_event(D, R) -> #{<<"division_id">> => D, <<"release_id">> => R, <<"release_name">> => <<"v1.0">>, <<"release_version">> => <<"1.0.0">>, <<"target_env">> => <<"prod">>, <<"deployed_by">> => <<"ops">>, <<"deployed_at">> => 2000}.
stage_event(D, S) -> #{<<"division_id">> => D, <<"stage_id">> => S, <<"release_id">> => <<"r-1">>, <<"stage_name">> => <<"canary">>, <<"stage_percentage">> => 10, <<"description">> => <<"10% canary">>, <<"staged_at">> => 3000}.
pause_event(D) -> #{<<"division_id">> => D, <<"paused_at">> => 4000, <<"reason">> => <<"issue">>}.
complete_event(D) -> #{<<"division_id">> => D, <<"completed_at">> => 5000}.
archive_event(D) -> #{<<"division_id">> => D}.

cqrs_integration_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
      fun start_projects/1, fun query_found/1, fun query_not_found/1,
      fun pause_updates/1, fun complete_updates/1, fun archive_updates/1,
      fun release_projects/1, fun stage_projects/1, fun idempotency/1, fun full_flow/1
    ]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = deployments_test_store_proxy:start("/tmp/test_deploys_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> deployments_test_store_proxy:stop(), ok.

start_projects(#{}) -> fun() -> ok = deployment_started_v1_to_sqlite_deployments:project(start_event(<<"d-1">>)),
    {ok, [{1}]} = query_deployments_store:query("SELECT COUNT(*) FROM deployments WHERE division_id = ?1", [<<"d-1">>]) end.
query_found(#{}) -> fun() -> ok = deployment_started_v1_to_sqlite_deployments:project(start_event(<<"d-q">>)),
    {ok, R} = get_deployment_by_division_id:get(<<"d-q">>), ?assertEqual(<<"d-q">>, maps:get(division_id, R)),
    ?assertNotEqual(0, maps:get(status, R) band ?DEPLOYMENT_ACTIVE) end.
query_not_found(#{}) -> fun() -> ?assertEqual({error, not_found}, get_deployment_by_division_id:get(<<"x">>)) end.
pause_updates(#{}) -> fun() -> ok = deployment_started_v1_to_sqlite_deployments:project(start_event(<<"d-p">>)),
    ok = deployment_lifecycle_to_sqlite_deployments:project_paused(pause_event(<<"d-p">>)),
    {ok, R} = get_deployment_by_division_id:get(<<"d-p">>), ?assertNotEqual(0, maps:get(status, R) band ?DEPLOYMENT_PAUSED) end.
complete_updates(#{}) -> fun() -> ok = deployment_started_v1_to_sqlite_deployments:project(start_event(<<"d-c">>)),
    ok = deployment_lifecycle_to_sqlite_deployments:project_completed(complete_event(<<"d-c">>)),
    {ok, R} = get_deployment_by_division_id:get(<<"d-c">>), ?assertNotEqual(0, maps:get(status, R) band ?DEPLOYMENT_COMPLETED) end.
archive_updates(#{}) -> fun() -> ok = deployment_started_v1_to_sqlite_deployments:project(start_event(<<"d-a">>)),
    ok = deployment_archived_v1_to_sqlite_deployments:project(archive_event(<<"d-a">>)),
    {ok, R} = get_deployment_by_division_id:get(<<"d-a">>), ?assertNotEqual(0, maps:get(status, R) band ?DEPLOYMENT_ARCHIVED) end.
release_projects(#{}) -> fun() -> ok = release_deployed_v1_to_sqlite_releases:project(release_event(<<"d-r">>, <<"r-1">>)),
    {ok, [Row]} = get_releases_page:get(#{division_id => <<"d-r">>}),
    ?assertEqual(<<"r-1">>, maps:get(release_id, Row)), ?assertEqual(<<"v1.0">>, maps:get(release_name, Row)) end.
stage_projects(#{}) -> fun() -> ok = rollout_staged_v1_to_sqlite_rollout_stages:project(stage_event(<<"d-s">>, <<"s-1">>)),
    {ok, [Row]} = get_rollout_stages_page:get(#{division_id => <<"d-s">>}),
    ?assertEqual(<<"s-1">>, maps:get(stage_id, Row)), ?assertEqual(<<"canary">>, maps:get(stage_name, Row)) end.
idempotency(#{}) -> fun() -> E = start_event(<<"d-i">>), ok = deployment_started_v1_to_sqlite_deployments:project(E),
    ok = deployment_started_v1_to_sqlite_deployments:project(E),
    {ok, [{1}]} = query_deployments_store:query("SELECT COUNT(*) FROM deployments WHERE division_id = ?1", [<<"d-i">>]) end.
full_flow(#{}) -> fun() -> ok = deployment_started_v1_to_sqlite_deployments:project(start_event(<<"d-f">>)),
    ok = release_deployed_v1_to_sqlite_releases:project(release_event(<<"d-f">>, <<"r-f">>)),
    ok = rollout_staged_v1_to_sqlite_rollout_stages:project(stage_event(<<"d-f">>, <<"s-f">>)),
    ok = deployment_lifecycle_to_sqlite_deployments:project_completed(complete_event(<<"d-f">>)),
    {ok, D} = get_deployment_by_division_id:get(<<"d-f">>), ?assertNotEqual(0, maps:get(status, D) band ?DEPLOYMENT_COMPLETED) end.
