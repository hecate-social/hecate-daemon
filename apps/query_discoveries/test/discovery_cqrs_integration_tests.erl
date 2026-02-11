%%% @doc L3 Integration Tests: CMD → PRJ flow for query_discoveries.
-module(discovery_cqrs_integration_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("discover_divisions/include/discovery_status.hrl").

start_event(VentureId) ->
    #{<<"event_type">> => <<"discovery_started_v1">>,
      <<"venture_id">> => VentureId,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

division_discovered_event(VentureId, DivId) ->
    #{<<"event_type">> => <<"division_discovered_v1">>,
      <<"division_id">> => DivId,
      <<"venture_id">> => VentureId,
      <<"context_name">> => <<"payments">>,
      <<"description">> => <<"Payment processing">>,
      <<"identified_by">> => <<"analyst">>,
      <<"discovered_at">> => 2000}.

pause_event(VentureId) ->
    #{<<"event_type">> => <<"discovery_paused_v1">>,
      <<"venture_id">> => VentureId,
      <<"paused_at">> => 3000,
      <<"reason">> => <<"review">>}.

complete_event(VentureId) ->
    #{<<"event_type">> => <<"discovery_completed_v1">>,
      <<"venture_id">> => VentureId,
      <<"completed_at">> => 4000}.

archive_event(VentureId) ->
    #{<<"event_type">> => <<"discovery_archived_v1">>,
      <<"venture_id">> => VentureId}.

cqrs_integration_test_() ->
    {foreach,
     fun setup/0,
     fun teardown/1,
     [
      fun start_projects_to_sqlite/1,
      fun query_by_venture_id_found/1,
      fun query_by_venture_id_not_found/1,
      fun pause_updates_status/1,
      fun complete_updates_status/1,
      fun archive_updates_status/1,
      fun division_discovered_projects/1,
      fun discovered_divisions_page/1,
      fun projection_idempotency/1,
      fun full_cqrs_flow/1
     ]}.

setup() ->
    application:ensure_all_started(esqlite),
    DbPath = "/tmp/test_discoveries_" ++
             integer_to_list(erlang:unique_integer([positive])) ++ ".db",
    {ok, _Pid} = discoveries_test_store_proxy:start(DbPath),
    #{db_path => DbPath}.

teardown(#{}) ->
    discoveries_test_store_proxy:stop(),
    ok.

start_projects_to_sqlite(#{}) ->
    fun() ->
        ok = discovery_started_v1_to_sqlite_discoveries:project(start_event(<<"v-1">>)),
        {ok, Rows} = query_discoveries_store:query(
            "SELECT COUNT(*) FROM discoveries WHERE venture_id = ?1", [<<"v-1">>]),
        ?assertEqual(1, count_from_row(Rows))
    end.

query_by_venture_id_found(#{}) ->
    fun() ->
        ok = discovery_started_v1_to_sqlite_discoveries:project(start_event(<<"v-qid">>)),
        {ok, Result} = get_discovery_by_venture_id:execute(<<"v-qid">>),
        ?assertEqual(<<"v-qid">>, maps:get(venture_id, Result)),
        ?assertEqual(1000, maps:get(started_at, Result)),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?DISCOVERY_INITIATED),
        ?assertNotEqual(0, Status band ?DISCOVERY_ACTIVE)
    end.

query_by_venture_id_not_found(#{}) ->
    fun() ->
        ?assertEqual({error, not_found}, get_discovery_by_venture_id:execute(<<"none">>))
    end.

pause_updates_status(#{}) ->
    fun() ->
        ok = discovery_started_v1_to_sqlite_discoveries:project(start_event(<<"v-p">>)),
        ok = discovery_lifecycle_to_sqlite_discoveries:project_paused(pause_event(<<"v-p">>)),
        {ok, Result} = get_discovery_by_venture_id:execute(<<"v-p">>),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?DISCOVERY_PAUSED),
        ?assertEqual(0, Status band ?DISCOVERY_ACTIVE)
    end.

complete_updates_status(#{}) ->
    fun() ->
        ok = discovery_started_v1_to_sqlite_discoveries:project(start_event(<<"v-c">>)),
        ok = discovery_lifecycle_to_sqlite_discoveries:project_completed(complete_event(<<"v-c">>)),
        {ok, Result} = get_discovery_by_venture_id:execute(<<"v-c">>),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?DISCOVERY_COMPLETED),
        ?assertEqual(0, Status band ?DISCOVERY_ACTIVE)
    end.

archive_updates_status(#{}) ->
    fun() ->
        ok = discovery_started_v1_to_sqlite_discoveries:project(start_event(<<"v-a">>)),
        ok = discovery_archived_v1_to_sqlite_discoveries:project(archive_event(<<"v-a">>)),
        {ok, Result} = get_discovery_by_venture_id:execute(<<"v-a">>),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?DISCOVERY_ARCHIVED),
        ?assertNotEqual(0, Status band ?DISCOVERY_INITIATED)
    end.

division_discovered_projects(#{}) ->
    fun() ->
        ok = division_discovered_v1_to_sqlite_discovered_divisions:project(
            division_discovered_event(<<"v-dd">>, <<"div-1">>)),
        {ok, [Row]} = get_discovered_divisions_page:execute(#{venture_id => <<"v-dd">>}),
        ?assertEqual(<<"div-1">>, maps:get(division_id, Row)),
        ?assertEqual(<<"payments">>, maps:get(context_name, Row))
    end.

discovered_divisions_page(#{}) ->
    fun() ->
        ok = division_discovered_v1_to_sqlite_discovered_divisions:project(
            division_discovered_event(<<"v-pg">>, <<"d-1">>)),
        E2 = (division_discovered_event(<<"v-pg">>, <<"d-2">>))#{
            <<"context_name">> => <<"billing">>, <<"discovered_at">> => 3000},
        ok = division_discovered_v1_to_sqlite_discovered_divisions:project(E2),
        {ok, All} = get_discovered_divisions_page:execute(#{venture_id => <<"v-pg">>}),
        ?assertEqual(2, length(All))
    end.

projection_idempotency(#{}) ->
    fun() ->
        Event = start_event(<<"v-idem">>),
        ok = discovery_started_v1_to_sqlite_discoveries:project(Event),
        ok = discovery_started_v1_to_sqlite_discoveries:project(Event),
        {ok, Rows} = query_discoveries_store:query(
            "SELECT COUNT(*) FROM discoveries WHERE venture_id = ?1", [<<"v-idem">>]),
        ?assertEqual(1, count_from_row(Rows))
    end.

full_cqrs_flow(#{}) ->
    fun() ->
        ok = discovery_started_v1_to_sqlite_discoveries:project(start_event(<<"v-full">>)),
        ok = division_discovered_v1_to_sqlite_discovered_divisions:project(
            division_discovered_event(<<"v-full">>, <<"d-full">>)),
        ok = discovery_lifecycle_to_sqlite_discoveries:project_completed(
            complete_event(<<"v-full">>)),
        {ok, Disc} = get_discovery_by_venture_id:execute(<<"v-full">>),
        ?assertNotEqual(0, maps:get(status, Disc) band ?DISCOVERY_COMPLETED),
        {ok, [_Div]} = get_discovered_divisions_page:execute(#{venture_id => <<"v-full">>})
    end.

count_from_row([[N]]) -> N;
count_from_row([{N}]) -> N.
