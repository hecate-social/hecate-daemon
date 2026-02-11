%%% @doc L4c: Projection row verification tests for query_discoveries.
-module(discovery_projection_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("discover_divisions/include/discovery_status.hrl").

projection_test_() ->
    {foreach,
     fun setup/0,
     fun teardown/1,
     [
      fun projection_creates_correct_row/1,
      fun projection_status_label_correct/1,
      fun archive_preserves_existing_bits/1,
      fun division_projection_all_fields/1
     ]}.

setup() ->
    application:ensure_all_started(esqlite),
    DbPath = "/tmp/test_proj_disc_" ++
             integer_to_list(erlang:unique_integer([positive])) ++ ".db",
    {ok, _Pid} = discoveries_test_store_proxy:start(DbPath),
    #{db_path => DbPath}.

teardown(#{}) ->
    discoveries_test_store_proxy:stop(),
    ok.

projection_creates_correct_row(#{}) ->
    fun() ->
        Event = #{<<"venture_id">> => <<"v-row">>,
                  <<"started_at">> => 12345,
                  <<"started_by">> => <<"user@host">>},
        ok = discovery_started_v1_to_sqlite_discoveries:project(Event),
        {ok, [Row]} = query_discoveries_store:query(
            "SELECT venture_id, status, started_at, started_by "
            "FROM discoveries WHERE venture_id = ?1", [<<"v-row">>]),
        {VId, Status, StartAt, StartBy} = Row,
        ?assertEqual(<<"v-row">>, VId),
        ?assertEqual(?DISCOVERY_INITIATED bor ?DISCOVERY_ACTIVE, Status),
        ?assertEqual(12345, StartAt),
        ?assertEqual(<<"user@host">>, StartBy)
    end.

projection_status_label_correct(#{}) ->
    fun() ->
        ok = discovery_started_v1_to_sqlite_discoveries:project(
            #{<<"venture_id">> => <<"v-lbl">>, <<"started_at">> => 1000}),
        {ok, [{Status, Label}]} = query_discoveries_store:query(
            "SELECT status, status_label FROM discoveries WHERE venture_id = ?1",
            [<<"v-lbl">>]),
        ExpectedLabel = evoq_bit_flags:to_string(Status, ?DISCOVERY_FLAG_MAP),
        ?assertEqual(ExpectedLabel, Label)
    end.

archive_preserves_existing_bits(#{}) ->
    fun() ->
        ok = discovery_started_v1_to_sqlite_discoveries:project(
            #{<<"venture_id">> => <<"v-bits">>, <<"started_at">> => 1000}),
        ok = discovery_archived_v1_to_sqlite_discoveries:project(
            #{<<"venture_id">> => <<"v-bits">>}),
        {ok, [{StatusAfter}]} = query_discoveries_store:query(
            "SELECT status FROM discoveries WHERE venture_id = ?1", [<<"v-bits">>]),
        ?assertEqual(?DISCOVERY_INITIATED bor ?DISCOVERY_ACTIVE bor ?DISCOVERY_ARCHIVED,
                     StatusAfter)
    end.

division_projection_all_fields(#{}) ->
    fun() ->
        Event = #{<<"division_id">> => <<"div-all">>,
                  <<"venture_id">> => <<"v-all">>,
                  <<"context_name">> => <<"payments">>,
                  <<"description">> => <<"Pay processing">>,
                  <<"identified_by">> => <<"analyst">>,
                  <<"discovered_at">> => 9000},
        ok = division_discovered_v1_to_sqlite_discovered_divisions:project(Event),
        {ok, [{DivId, VId, Ctx, Desc, By, At}]} = query_discoveries_store:query(
            "SELECT division_id, venture_id, context_name, description, "
            "identified_by, discovered_at FROM discovered_divisions WHERE division_id = ?1",
            [<<"div-all">>]),
        ?assertEqual(<<"div-all">>, DivId),
        ?assertEqual(<<"v-all">>, VId),
        ?assertEqual(<<"payments">>, Ctx),
        ?assertEqual(<<"Pay processing">>, Desc),
        ?assertEqual(<<"analyst">>, By),
        ?assertEqual(9000, At)
    end.
