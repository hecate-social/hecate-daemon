%%% @doc L3 Integration Tests: CMD → PRJ flow for query_designs.
%%% Tests projection → SQLite → query for designs, designed_aggregates, designed_events.
-module(design_cqrs_integration_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("design_division/include/design_status.hrl").

%% ===================================================================
%% Event fixtures
%% ===================================================================

start_event(DivisionId) ->
    #{<<"event_type">> => <<"design_started_v1">>,
      <<"division_id">> => DivisionId,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

aggregate_designed_event(DivisionId, AggId) ->
    #{<<"event_type">> => <<"aggregate_designed_v1">>,
      <<"division_id">> => DivisionId,
      <<"aggregate_id">> => AggId,
      <<"aggregate_name">> => <<"order">>,
      <<"stream_pattern">> => <<"order-{id}">>,
      <<"status_flags">> => [#{<<"name">> => <<"active">>, <<"bit">> => 1}],
      <<"description">> => <<"Order aggregate">>,
      <<"designed_by">> => <<"architect">>,
      <<"designed_at">> => 2000}.

event_designed_event(DivisionId, EvtId) ->
    #{<<"event_type">> => <<"event_designed_v1">>,
      <<"division_id">> => DivisionId,
      <<"event_id">> => EvtId,
      <<"event_name">> => <<"order_placed_v1">>,
      <<"aggregate_name">> => <<"order">>,
      <<"payload_fields">> => [#{<<"name">> => <<"amount">>, <<"type">> => <<"integer">>}],
      <<"description">> => <<"Order placed event">>,
      <<"designed_by">> => <<"architect">>,
      <<"designed_at">> => 3000}.

pause_event(DivisionId) ->
    #{<<"event_type">> => <<"design_paused_v1">>,
      <<"division_id">> => DivisionId,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"review needed">>}.

resume_event(DivisionId) ->
    #{<<"event_type">> => <<"design_resumed_v1">>,
      <<"division_id">> => DivisionId}.

complete_event(DivisionId) ->
    #{<<"event_type">> => <<"design_completed_v1">>,
      <<"division_id">> => DivisionId,
      <<"completed_at">> => 5000}.

archive_event(DivisionId) ->
    #{<<"event_type">> => <<"design_archived_v1">>,
      <<"division_id">> => DivisionId,
      <<"archived_by">> => <<"admin">>,
      <<"reason">> => <<"cleanup">>}.

%% ===================================================================
%% Test suite
%% ===================================================================

cqrs_integration_test_() ->
    {foreach,
     fun setup/0,
     fun teardown/1,
     [
      fun start_projects_to_sqlite/1,
      fun query_design_by_id_found/1,
      fun query_design_by_id_not_found/1,
      fun pause_updates_status/1,
      fun resume_restores_active/1,
      fun complete_updates_status/1,
      fun archive_updates_status/1,
      fun aggregate_designed_projects/1,
      fun event_designed_projects/1,
      fun aggregates_page_query/1,
      fun projection_idempotency/1,
      fun full_cqrs_flow/1
     ]}.

setup() ->
    application:ensure_all_started(esqlite),
    DbPath = "/tmp/test_designs_" ++
             integer_to_list(erlang:unique_integer([positive])) ++ ".db",
    {ok, _Pid} = designs_test_store_proxy:start(DbPath),
    #{db_path => DbPath}.

teardown(#{}) ->
    designs_test_store_proxy:stop(),
    ok.

%% ===================================================================
%% Test cases
%% ===================================================================

start_projects_to_sqlite(#{}) ->
    fun() ->
        Event = start_event(<<"div-1">>),
        ok = design_started_v1_to_sqlite_designs:project(Event),
        {ok, Rows} = query_designs_store:query(
            "SELECT COUNT(*) FROM designs WHERE division_id = ?1", [<<"div-1">>]),
        ?assertEqual(1, count_from_row(Rows))
    end.

query_design_by_id_found(#{}) ->
    fun() ->
        ok = design_started_v1_to_sqlite_designs:project(start_event(<<"div-qid">>)),
        {ok, Result} = get_design_by_division_id:get(<<"div-qid">>),
        ?assertEqual(<<"div-qid">>, maps:get(division_id, Result)),
        ?assertEqual(1000, maps:get(started_at, Result)),
        ?assertEqual(<<"test@host">>, maps:get(started_by, Result)),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?DESIGN_INITIATED),
        ?assertNotEqual(0, Status band ?DESIGN_ACTIVE)
    end.

query_design_by_id_not_found(#{}) ->
    fun() ->
        ?assertEqual({error, not_found}, get_design_by_division_id:get(<<"nonexistent">>))
    end.

pause_updates_status(#{}) ->
    fun() ->
        ok = design_started_v1_to_sqlite_designs:project(start_event(<<"div-pause">>)),
        ok = design_lifecycle_to_sqlite_designs:project_paused(pause_event(<<"div-pause">>)),
        {ok, Result} = get_design_by_division_id:get(<<"div-pause">>),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?DESIGN_PAUSED),
        ?assertEqual(0, Status band ?DESIGN_ACTIVE),
        ?assertEqual(4000, maps:get(paused_at, Result)),
        ?assertEqual(<<"review needed">>, maps:get(pause_reason, Result))
    end.

resume_restores_active(#{}) ->
    fun() ->
        ok = design_started_v1_to_sqlite_designs:project(start_event(<<"div-resume">>)),
        ok = design_lifecycle_to_sqlite_designs:project_paused(pause_event(<<"div-resume">>)),
        ok = design_lifecycle_to_sqlite_designs:project_resumed(resume_event(<<"div-resume">>)),
        {ok, Result} = get_design_by_division_id:get(<<"div-resume">>),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?DESIGN_ACTIVE),
        ?assertEqual(0, Status band ?DESIGN_PAUSED)
    end.

complete_updates_status(#{}) ->
    fun() ->
        ok = design_started_v1_to_sqlite_designs:project(start_event(<<"div-comp">>)),
        ok = design_lifecycle_to_sqlite_designs:project_completed(complete_event(<<"div-comp">>)),
        {ok, Result} = get_design_by_division_id:get(<<"div-comp">>),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?DESIGN_COMPLETED),
        ?assertEqual(0, Status band ?DESIGN_ACTIVE),
        ?assertEqual(5000, maps:get(completed_at, Result))
    end.

archive_updates_status(#{}) ->
    fun() ->
        ok = design_started_v1_to_sqlite_designs:project(start_event(<<"div-arch">>)),
        ok = design_archived_v1_to_sqlite_designs:project(archive_event(<<"div-arch">>)),
        {ok, Result} = get_design_by_division_id:get(<<"div-arch">>),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?DESIGN_ARCHIVED),
        ?assertNotEqual(0, Status band ?DESIGN_INITIATED)
    end.

aggregate_designed_projects(#{}) ->
    fun() ->
        ok = aggregate_designed_v1_to_sqlite_designed_aggregates:project(
            aggregate_designed_event(<<"div-agg">>, <<"agg-1">>)),
        {ok, [Row]} = get_designed_aggregates_page:get(#{division_id => <<"div-agg">>}),
        ?assertEqual(<<"agg-1">>, maps:get(aggregate_id, Row)),
        ?assertEqual(<<"order">>, maps:get(aggregate_name, Row)),
        ?assertEqual(<<"order-{id}">>, maps:get(stream_pattern, Row))
    end.

event_designed_projects(#{}) ->
    fun() ->
        ok = event_designed_v1_to_sqlite_designed_events:project(
            event_designed_event(<<"div-evt">>, <<"evt-1">>)),
        {ok, [Row]} = get_designed_events_page:get(#{division_id => <<"div-evt">>}),
        ?assertEqual(<<"evt-1">>, maps:get(event_id, Row)),
        ?assertEqual(<<"order_placed_v1">>, maps:get(event_name, Row)),
        ?assertEqual(<<"order">>, maps:get(aggregate_name, Row))
    end.

aggregates_page_query(#{}) ->
    fun() ->
        ok = aggregate_designed_v1_to_sqlite_designed_aggregates:project(
            aggregate_designed_event(<<"div-page">>, <<"agg-p1">>)),
        E2 = (aggregate_designed_event(<<"div-page">>, <<"agg-p2">>))#{
            <<"aggregate_name">> => <<"product">>, <<"designed_at">> => 3000},
        ok = aggregate_designed_v1_to_sqlite_designed_aggregates:project(E2),
        {ok, All} = get_designed_aggregates_page:get(#{division_id => <<"div-page">>}),
        ?assertEqual(2, length(All)),
        {ok, [One]} = get_designed_aggregates_page:get(
            #{division_id => <<"div-page">>, limit => 1}),
        ?assertEqual(1, length([One]))
    end.

projection_idempotency(#{}) ->
    fun() ->
        Event = start_event(<<"div-idem">>),
        ok = design_started_v1_to_sqlite_designs:project(Event),
        ok = design_started_v1_to_sqlite_designs:project(Event),
        {ok, Rows} = query_designs_store:query(
            "SELECT COUNT(*) FROM designs WHERE division_id = ?1", [<<"div-idem">>]),
        ?assertEqual(1, count_from_row(Rows))
    end.

full_cqrs_flow(#{}) ->
    fun() ->
        DivId = <<"div-full">>,
        ok = design_started_v1_to_sqlite_designs:project(start_event(DivId)),
        ok = aggregate_designed_v1_to_sqlite_designed_aggregates:project(
            aggregate_designed_event(DivId, <<"agg-full">>)),
        ok = event_designed_v1_to_sqlite_designed_events:project(
            event_designed_event(DivId, <<"evt-full">>)),
        ok = design_lifecycle_to_sqlite_designs:project_completed(complete_event(DivId)),
        {ok, Design} = get_design_by_division_id:get(DivId),
        ?assertNotEqual(0, maps:get(status, Design) band ?DESIGN_COMPLETED),
        {ok, [_Agg]} = get_designed_aggregates_page:get(#{division_id => DivId}),
        {ok, [_Evt]} = get_designed_events_page:get(#{division_id => DivId})
    end.

%% ===================================================================
%% Helpers
%% ===================================================================

count_from_row([[N]]) -> N;
count_from_row([{N}]) -> N.
