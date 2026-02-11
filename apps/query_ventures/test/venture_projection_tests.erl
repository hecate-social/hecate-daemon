%%% @doc Layer 4c: Projection row verification tests.
%%% Tests that projections write correct SQLite rows with proper
%%% status labels, JSON-encoded fields, and bit flag computations.
-module(venture_projection_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("setup_venture/include/venture_status.hrl").

%% ===================================================================
%% Test suite
%% ===================================================================

projection_test_() ->
    {foreach,
     fun setup/0,
     fun teardown/1,
     [
      fun projection_creates_correct_row/1,
      fun projection_status_label_correct/1,
      fun projection_json_fields_encode/1,
      fun projection_undefined_fields_handled/1,
      fun archive_projection_status_label_correct/1,
      fun archive_preserves_existing_bits/1
     ]}.

setup() ->
    application:ensure_all_started(esqlite),
    DbPath = "/tmp/test_proj_" ++
             integer_to_list(erlang:unique_integer([positive])) ++ ".db",
    {ok, _Pid} = test_store_proxy:start(DbPath),
    #{db_path => DbPath}.

teardown(#{}) ->
    test_store_proxy:stop(),
    ok.

%% ===================================================================
%% Test cases
%% ===================================================================

%% Projection creates row with all correct column values
projection_creates_correct_row(#{}) ->
    fun() ->
        Event = #{<<"event_type">> => <<"venture_setup_v1">>,
                  <<"venture_id">> => <<"v-row">>,
                  <<"name">> => <<"RowTest">>,
                  <<"brief">> => <<"testing row">>,
                  <<"repos">> => [<<"r1">>],
                  <<"skills">> => [<<"s1">>],
                  <<"context_map">> => #{<<"k">> => <<"v">>},
                  <<"initiated_at">> => 12345,
                  <<"initiated_by">> => <<"user@host">>},
        ok = venture_setup_v1_to_sqlite_ventures:project(Event),
        {ok, [Row]} = query_ventures_store:query(
            "SELECT venture_id, name, brief, status, status_label, "
            "repos, skills, context_map, initiated_at, initiated_by "
            "FROM ventures WHERE venture_id = ?1", [<<"v-row">>]),
        %% Extract values (handles both tuple and list format)
        Values = to_list(Row),
        [VId, Name, Brief, Status, _Label, Repos, Skills, CtxMap, InitAt, InitBy] = Values,
        ?assertEqual(<<"v-row">>, VId),
        ?assertEqual(<<"RowTest">>, Name),
        ?assertEqual(<<"testing row">>, Brief),
        ?assertEqual(?VENTURE_SETUP, Status),
        ?assertEqual([<<"r1">>], json:decode(Repos)),
        ?assertEqual([<<"s1">>], json:decode(Skills)),
        ?assertEqual(#{<<"k">> => <<"v">>}, json:decode(CtxMap)),
        ?assertEqual(12345, InitAt),
        ?assertEqual(<<"user@host">>, InitBy)
    end.

%% Status label matches evoq_bit_flags:to_string output
projection_status_label_correct(#{}) ->
    fun() ->
        Event = #{<<"event_type">> => <<"venture_setup_v1">>,
                  <<"venture_id">> => <<"v-label">>,
                  <<"name">> => <<"LabelTest">>,
                  <<"initiated_at">> => 1000},
        ok = venture_setup_v1_to_sqlite_ventures:project(Event),
        {ok, [Row]} = query_ventures_store:query(
            "SELECT status, status_label FROM ventures WHERE venture_id = ?1",
            [<<"v-label">>]),
        [Status, Label] = to_list(Row),
        ExpectedLabel = evoq_bit_flags:to_string(Status, ?VENTURE_FLAG_MAP),
        ?assertEqual(ExpectedLabel, Label)
    end.

%% JSON fields are properly encoded
projection_json_fields_encode(#{}) ->
    fun() ->
        Event = #{<<"event_type">> => <<"venture_setup_v1">>,
                  <<"venture_id">> => <<"v-json">>,
                  <<"name">> => <<"JsonTest">>,
                  <<"repos">> => [<<"repo1">>, <<"repo2">>],
                  <<"skills">> => [<<"erl">>, <<"go">>],
                  <<"context_map">> => #{<<"nested">> => #{<<"deep">> => true}},
                  <<"initiated_at">> => 1000},
        ok = venture_setup_v1_to_sqlite_ventures:project(Event),
        {ok, [Row]} = query_ventures_store:query(
            "SELECT repos, skills, context_map FROM ventures WHERE venture_id = ?1",
            [<<"v-json">>]),
        [ReposJson, SkillsJson, CtxJson] = to_list(Row),
        ?assertEqual([<<"repo1">>, <<"repo2">>], json:decode(ReposJson)),
        ?assertEqual([<<"erl">>, <<"go">>], json:decode(SkillsJson)),
        ?assertEqual(#{<<"nested">> => #{<<"deep">> => true}}, json:decode(CtxJson))
    end.

%% Undefined optional fields are stored as NULL
projection_undefined_fields_handled(#{}) ->
    fun() ->
        Event = #{<<"event_type">> => <<"venture_setup_v1">>,
                  <<"venture_id">> => <<"v-null">>,
                  <<"name">> => <<"NullTest">>,
                  <<"initiated_at">> => 1000},
        ok = venture_setup_v1_to_sqlite_ventures:project(Event),
        {ok, Result} = get_venture_by_id:execute(<<"v-null">>),
        ?assertEqual(undefined, maps:get(brief, Result)),
        ?assertEqual(undefined, maps:get(repos, Result)),
        ?assertEqual(undefined, maps:get(skills, Result)),
        ?assertEqual(undefined, maps:get(context_map, Result))
    end.

%% Archive projection computes correct status_label with all bits
archive_projection_status_label_correct(#{}) ->
    fun() ->
        SetupEvent = #{<<"event_type">> => <<"venture_setup_v1">>,
                       <<"venture_id">> => <<"v-alabel">>,
                       <<"name">> => <<"ArchLabel">>,
                       <<"initiated_at">> => 1000},
        ArchiveEvent = #{<<"event_type">> => <<"venture_archived_v1">>,
                         <<"venture_id">> => <<"v-alabel">>},
        ok = venture_setup_v1_to_sqlite_ventures:project(SetupEvent),
        ok = venture_archived_v1_to_sqlite_ventures:project(ArchiveEvent),
        {ok, [Row]} = query_ventures_store:query(
            "SELECT status, status_label FROM ventures WHERE venture_id = ?1",
            [<<"v-alabel">>]),
        [Status, Label] = to_list(Row),
        ExpectedLabel = evoq_bit_flags:to_string(Status, ?VENTURE_FLAG_MAP),
        ?assertEqual(ExpectedLabel, Label),
        ?assertNotEqual(0, Status band ?VENTURE_ARCHIVED),
        ?assertNotEqual(0, Status band ?VENTURE_SETUP)
    end.

%% Archive preserves existing status bits (bitwise OR)
archive_preserves_existing_bits(#{}) ->
    fun() ->
        SetupEvent = #{<<"event_type">> => <<"venture_setup_v1">>,
                       <<"venture_id">> => <<"v-bits">>,
                       <<"name">> => <<"BitsTest">>,
                       <<"initiated_at">> => 1000},
        ok = venture_setup_v1_to_sqlite_ventures:project(SetupEvent),
        {ok, [R1]} = query_ventures_store:query(
            "SELECT status FROM ventures WHERE venture_id = ?1", [<<"v-bits">>]),
        [StatusBefore] = to_list(R1),
        ?assertEqual(?VENTURE_SETUP, StatusBefore),

        ArchiveEvent = #{<<"event_type">> => <<"venture_archived_v1">>,
                         <<"venture_id">> => <<"v-bits">>},
        ok = venture_archived_v1_to_sqlite_ventures:project(ArchiveEvent),
        {ok, [R2]} = query_ventures_store:query(
            "SELECT status FROM ventures WHERE venture_id = ?1", [<<"v-bits">>]),
        [StatusAfter] = to_list(R2),
        %% Both SETUP and ARCHIVED bits should be set
        ?assertEqual(?VENTURE_SETUP bor ?VENTURE_ARCHIVED, StatusAfter)
    end.

%% ===================================================================
%% Internal helpers
%% ===================================================================

to_list(T) when is_tuple(T) -> tuple_to_list(T);
to_list(L) when is_list(L) -> L.
