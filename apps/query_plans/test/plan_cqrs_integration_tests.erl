%%% @doc L3 Integration Tests for query_plans.
-module(plan_cqrs_integration_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("plan_division/include/plan_status.hrl").

start_event(DivId) -> #{<<"event_type">> => <<"plan_started_v1">>, <<"division_id">> => DivId, <<"started_at">> => 1000, <<"started_by">> => <<"test@host">>}.
desk_event(DivId, DeskId) -> #{<<"event_type">> => <<"desk_planned_v1">>, <<"division_id">> => DivId, <<"desk_id">> => DeskId, <<"desk_name">> => <<"register_user">>, <<"department">> => <<"CMD">>, <<"aggregate_name">> => <<"user">>, <<"description">> => <<"User registration">>, <<"priority">> => 1, <<"planned_by">> => <<"planner">>, <<"planned_at">> => 2000}.
dep_event(DivId, DepId) -> #{<<"event_type">> => <<"dependency_planned_v1">>, <<"division_id">> => DivId, <<"dependency_id">> => DepId, <<"from_desk">> => <<"desk_a">>, <<"to_desk">> => <<"desk_b">>, <<"dependency_type">> => <<"data">>, <<"description">> => <<"A needs B">>, <<"planned_by">> => <<"planner">>, <<"planned_at">> => 3000}.
pause_event(DivId) -> #{<<"division_id">> => DivId, <<"paused_at">> => 4000, <<"reason">> => <<"review">>}.
complete_event(DivId) -> #{<<"division_id">> => DivId, <<"completed_at">> => 5000}.
archive_event(DivId) -> #{<<"division_id">> => DivId}.

cqrs_integration_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
      fun start_projects/1, fun query_by_id_found/1, fun query_by_id_not_found/1,
      fun pause_updates/1, fun complete_updates/1, fun archive_updates/1,
      fun desk_projects/1, fun dependency_projects/1, fun idempotency/1, fun full_flow/1
    ]}.

setup() ->
    application:ensure_all_started(esqlite),
    DbPath = "/tmp/test_plans_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db",
    {ok, _} = plans_test_store_proxy:start(DbPath), #{}.

teardown(#{}) -> plans_test_store_proxy:stop(), ok.

start_projects(#{}) -> fun() ->
    ok = plan_started_v1_to_sqlite_plans:project(start_event(<<"d-1">>)),
    {ok, [{1}]} = query_plans_store:query("SELECT COUNT(*) FROM plans WHERE division_id = ?1", [<<"d-1">>])
end.

query_by_id_found(#{}) -> fun() ->
    ok = plan_started_v1_to_sqlite_plans:project(start_event(<<"d-q">>)),
    {ok, R} = get_plan_by_division_id:get(<<"d-q">>),
    ?assertEqual(<<"d-q">>, maps:get(division_id, R)),
    ?assertNotEqual(0, maps:get(status, R) band ?PLAN_ACTIVE)
end.

query_by_id_not_found(#{}) -> fun() ->
    ?assertEqual({error, not_found}, get_plan_by_division_id:get(<<"none">>))
end.

pause_updates(#{}) -> fun() ->
    ok = plan_started_v1_to_sqlite_plans:project(start_event(<<"d-p">>)),
    ok = plan_lifecycle_to_sqlite_plans:project_paused(pause_event(<<"d-p">>)),
    {ok, R} = get_plan_by_division_id:get(<<"d-p">>),
    ?assertNotEqual(0, maps:get(status, R) band ?PLAN_PAUSED),
    ?assertEqual(0, maps:get(status, R) band ?PLAN_ACTIVE)
end.

complete_updates(#{}) -> fun() ->
    ok = plan_started_v1_to_sqlite_plans:project(start_event(<<"d-c">>)),
    ok = plan_lifecycle_to_sqlite_plans:project_completed(complete_event(<<"d-c">>)),
    {ok, R} = get_plan_by_division_id:get(<<"d-c">>),
    ?assertNotEqual(0, maps:get(status, R) band ?PLAN_COMPLETED)
end.

archive_updates(#{}) -> fun() ->
    ok = plan_started_v1_to_sqlite_plans:project(start_event(<<"d-a">>)),
    ok = plan_archived_v1_to_sqlite_plans:project(archive_event(<<"d-a">>)),
    {ok, R} = get_plan_by_division_id:get(<<"d-a">>),
    ?assertNotEqual(0, maps:get(status, R) band ?PLAN_ARCHIVED)
end.

desk_projects(#{}) -> fun() ->
    ok = desk_planned_v1_to_sqlite_planned_desks:project(desk_event(<<"d-dk">>, <<"dk-1">>)),
    {ok, [Row]} = get_planned_desks_page:get(#{division_id => <<"d-dk">>}),
    ?assertEqual(<<"dk-1">>, maps:get(desk_id, Row)),
    ?assertEqual(<<"register_user">>, maps:get(desk_name, Row))
end.

dependency_projects(#{}) -> fun() ->
    ok = dependency_planned_v1_to_sqlite_planned_dependencies:project(dep_event(<<"d-dp">>, <<"dep-1">>)),
    {ok, [Row]} = get_planned_dependencies_page:get(#{division_id => <<"d-dp">>}),
    ?assertEqual(<<"dep-1">>, maps:get(dependency_id, Row)),
    ?assertEqual(<<"desk_a">>, maps:get(from_desk, Row))
end.

idempotency(#{}) -> fun() ->
    E = start_event(<<"d-i">>),
    ok = plan_started_v1_to_sqlite_plans:project(E),
    ok = plan_started_v1_to_sqlite_plans:project(E),
    {ok, [{1}]} = query_plans_store:query("SELECT COUNT(*) FROM plans WHERE division_id = ?1", [<<"d-i">>])
end.

full_flow(#{}) -> fun() ->
    ok = plan_started_v1_to_sqlite_plans:project(start_event(<<"d-f">>)),
    ok = desk_planned_v1_to_sqlite_planned_desks:project(desk_event(<<"d-f">>, <<"dk-f">>)),
    ok = dependency_planned_v1_to_sqlite_planned_dependencies:project(dep_event(<<"d-f">>, <<"dep-f">>)),
    ok = plan_lifecycle_to_sqlite_plans:project_completed(complete_event(<<"d-f">>)),
    {ok, P} = get_plan_by_division_id:get(<<"d-f">>),
    ?assertNotEqual(0, maps:get(status, P) band ?PLAN_COMPLETED),
    {ok, [_]} = get_planned_desks_page:get(#{division_id => <<"d-f">>}),
    {ok, [_]} = get_planned_dependencies_page:get(#{division_id => <<"d-f">>})
end.
