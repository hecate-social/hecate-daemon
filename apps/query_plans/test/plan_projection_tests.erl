%%% @doc L4c: Projection row verification tests for query_plans.
-module(plan_projection_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("plan_division/include/plan_status.hrl").

projection_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
      fun correct_status_flags/1, fun status_label_correct/1,
      fun archive_preserves_bits/1, fun desk_all_fields/1
    ]}.

setup() ->
    application:ensure_all_started(esqlite),
    DbPath = "/tmp/test_proj_plans_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db",
    {ok, _} = plans_test_store_proxy:start(DbPath), #{}.
teardown(#{}) -> plans_test_store_proxy:stop(), ok.

correct_status_flags(#{}) -> fun() ->
    ok = plan_started_v1_to_sqlite_plans:project(
        #{<<"division_id">> => <<"d-sf">>, <<"started_at">> => 1000, <<"started_by">> => <<"t">>}),
    {ok, [{_, Status, _, _, _}]} = query_plans_store:query(
        "SELECT division_id, status, status_label, started_at, started_by FROM plans WHERE division_id = ?1", [<<"d-sf">>]),
    ?assertEqual(?PLAN_INITIATED bor ?PLAN_ACTIVE, Status)
end.

status_label_correct(#{}) -> fun() ->
    ok = plan_started_v1_to_sqlite_plans:project(
        #{<<"division_id">> => <<"d-lb">>, <<"started_at">> => 1000}),
    {ok, [{Status, Label}]} = query_plans_store:query(
        "SELECT status, status_label FROM plans WHERE division_id = ?1", [<<"d-lb">>]),
    ?assertEqual(evoq_bit_flags:to_string(Status, ?PLAN_FLAG_MAP), Label)
end.

archive_preserves_bits(#{}) -> fun() ->
    ok = plan_started_v1_to_sqlite_plans:project(
        #{<<"division_id">> => <<"d-ab">>, <<"started_at">> => 1000}),
    ok = plan_archived_v1_to_sqlite_plans:project(#{<<"division_id">> => <<"d-ab">>}),
    {ok, [{S}]} = query_plans_store:query("SELECT status FROM plans WHERE division_id = ?1", [<<"d-ab">>]),
    ?assertEqual(?PLAN_INITIATED bor ?PLAN_ACTIVE bor ?PLAN_ARCHIVED, S)
end.

desk_all_fields(#{}) -> fun() ->
    ok = desk_planned_v1_to_sqlite_planned_desks:project(
        #{<<"desk_id">> => <<"dk-af">>, <<"division_id">> => <<"d-af">>, <<"desk_name">> => <<"reg_user">>,
          <<"department">> => <<"CMD">>, <<"aggregate_name">> => <<"user">>,
          <<"description">> => <<"desc">>, <<"priority">> => 5,
          <<"planned_by">> => <<"planner">>, <<"planned_at">> => 9000}),
    {ok, [{DkId, DivId, Name, Dept, Agg, Desc, Prio, By, At}]} = query_plans_store:query(
        "SELECT desk_id, division_id, desk_name, department, aggregate_name, description, priority, planned_by, planned_at "
        "FROM planned_desks WHERE desk_id = ?1", [<<"dk-af">>]),
    ?assertEqual(<<"dk-af">>, DkId), ?assertEqual(<<"d-af">>, DivId),
    ?assertEqual(<<"reg_user">>, Name), ?assertEqual(<<"CMD">>, Dept),
    ?assertEqual(<<"user">>, Agg), ?assertEqual(<<"desc">>, Desc),
    ?assertEqual(5, Prio), ?assertEqual(<<"planner">>, By), ?assertEqual(9000, At)
end.
