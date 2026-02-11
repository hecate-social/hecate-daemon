%%% @doc L4c: Projection row verification tests for query_designs.
-module(design_projection_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("design_division/include/design_status.hrl").

projection_test_() ->
    {foreach,
     fun setup/0,
     fun teardown/1,
     [
      fun projection_creates_correct_row/1,
      fun projection_status_label_correct/1,
      fun projection_undefined_fields_handled/1,
      fun archive_preserves_existing_bits/1,
      fun aggregate_projection_json_fields/1,
      fun event_projection_json_fields/1
     ]}.

setup() ->
    application:ensure_all_started(esqlite),
    DbPath = "/tmp/test_proj_designs_" ++
             integer_to_list(erlang:unique_integer([positive])) ++ ".db",
    {ok, _Pid} = designs_test_store_proxy:start(DbPath),
    #{db_path => DbPath}.

teardown(#{}) ->
    designs_test_store_proxy:stop(),
    ok.

projection_creates_correct_row(#{}) ->
    fun() ->
        Event = #{<<"event_type">> => <<"design_started_v1">>,
                  <<"division_id">> => <<"d-row">>,
                  <<"started_at">> => 12345,
                  <<"started_by">> => <<"user@host">>},
        ok = design_started_v1_to_sqlite_designs:project(Event),
        {ok, [Row]} = query_designs_store:query(
            "SELECT division_id, status, status_label, started_at, started_by "
            "FROM designs WHERE division_id = ?1", [<<"d-row">>]),
        [DivId, Status, _Label, StartAt, StartBy] = to_list(Row),
        ?assertEqual(<<"d-row">>, DivId),
        ExpectedStatus = ?DESIGN_INITIATED bor ?DESIGN_ACTIVE,
        ?assertEqual(ExpectedStatus, Status),
        ?assertEqual(12345, StartAt),
        ?assertEqual(<<"user@host">>, StartBy)
    end.

projection_status_label_correct(#{}) ->
    fun() ->
        Event = #{<<"division_id">> => <<"d-label">>,
                  <<"started_at">> => 1000,
                  <<"started_by">> => <<"test">>},
        ok = design_started_v1_to_sqlite_designs:project(Event),
        {ok, [Row]} = query_designs_store:query(
            "SELECT status, status_label FROM designs WHERE division_id = ?1",
            [<<"d-label">>]),
        [Status, Label] = to_list(Row),
        ExpectedLabel = evoq_bit_flags:to_string(Status, ?DESIGN_FLAG_MAP),
        ?assertEqual(ExpectedLabel, Label)
    end.

projection_undefined_fields_handled(#{}) ->
    fun() ->
        Event = #{<<"division_id">> => <<"d-null">>,
                  <<"started_at">> => 1000},
        ok = design_started_v1_to_sqlite_designs:project(Event),
        {ok, Result} = get_design_by_division_id:get(<<"d-null">>),
        ?assertEqual(undefined, maps:get(started_by, Result, undefined))
    end.

archive_preserves_existing_bits(#{}) ->
    fun() ->
        ok = design_started_v1_to_sqlite_designs:project(
            #{<<"division_id">> => <<"d-bits">>,
              <<"started_at">> => 1000}),
        {ok, [R1]} = query_designs_store:query(
            "SELECT status FROM designs WHERE division_id = ?1", [<<"d-bits">>]),
        [StatusBefore] = to_list(R1),
        ?assertEqual(?DESIGN_INITIATED bor ?DESIGN_ACTIVE, StatusBefore),
        ok = design_archived_v1_to_sqlite_designs:project(
            #{<<"division_id">> => <<"d-bits">>}),
        {ok, [R2]} = query_designs_store:query(
            "SELECT status FROM designs WHERE division_id = ?1", [<<"d-bits">>]),
        [StatusAfter] = to_list(R2),
        ?assertEqual(?DESIGN_INITIATED bor ?DESIGN_ACTIVE bor ?DESIGN_ARCHIVED, StatusAfter)
    end.

aggregate_projection_json_fields(#{}) ->
    fun() ->
        Event = #{<<"aggregate_id">> => <<"agg-json">>,
                  <<"division_id">> => <<"d-json">>,
                  <<"aggregate_name">> => <<"order">>,
                  <<"stream_pattern">> => <<"order-{id}">>,
                  <<"status_flags">> => [#{<<"name">> => <<"active">>, <<"bit">> => 1}],
                  <<"description">> => <<"test">>,
                  <<"designed_by">> => <<"arch">>,
                  <<"designed_at">> => 5000},
        ok = aggregate_designed_v1_to_sqlite_designed_aggregates:project(Event),
        {ok, [Row]} = query_designs_store:query(
            "SELECT status_flags FROM designed_aggregates WHERE aggregate_id = ?1",
            [<<"agg-json">>]),
        [FlagsJson] = to_list(Row),
        Decoded = json:decode(FlagsJson),
        ?assert(is_list(Decoded)),
        [First | _] = Decoded,
        ?assertEqual(<<"active">>, maps:get(<<"name">>, First))
    end.

event_projection_json_fields(#{}) ->
    fun() ->
        Event = #{<<"event_id">> => <<"evt-json">>,
                  <<"division_id">> => <<"d-json2">>,
                  <<"event_name">> => <<"order_placed_v1">>,
                  <<"aggregate_name">> => <<"order">>,
                  <<"payload_fields">> => [#{<<"name">> => <<"amount">>}],
                  <<"description">> => <<"test event">>,
                  <<"designed_by">> => <<"arch">>,
                  <<"designed_at">> => 6000},
        ok = event_designed_v1_to_sqlite_designed_events:project(Event),
        {ok, [Row]} = query_designs_store:query(
            "SELECT payload_fields FROM designed_events WHERE event_id = ?1",
            [<<"evt-json">>]),
        [FieldsJson] = to_list(Row),
        Decoded = json:decode(FieldsJson),
        ?assert(is_list(Decoded))
    end.

to_list(T) when is_tuple(T) -> tuple_to_list(T);
to_list(L) when is_list(L) -> L.
