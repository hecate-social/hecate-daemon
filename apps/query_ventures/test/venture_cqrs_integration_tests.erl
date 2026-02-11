%%% @doc Layer 3: Integration Tests — CMD to PRJ flow.
%%% Tests the full CQRS read-side: projection -> SQLite -> query.
%%% Uses test_store_proxy to provide a fresh SQLite DB per test group.
-module(venture_cqrs_integration_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("setup_venture/include/venture_status.hrl").

%% ===================================================================
%% Test fixtures: event maps
%% ===================================================================

setup_event(VentureId) ->
    #{<<"event_type">> => <<"venture_setup_v1">>,
      <<"venture_id">> => VentureId,
      <<"name">> => <<"Test Venture">>,
      <<"brief">> => <<"A test venture">>,
      <<"repos">> => [<<"repo1">>, <<"repo2">>],
      <<"skills">> => [<<"erlang">>, <<"otp">>],
      <<"context_map">> => #{<<"key">> => <<"value">>},
      <<"initiated_at">> => 1000,
      <<"initiated_by">> => <<"test@host">>}.

archive_event(VentureId) ->
    #{<<"event_type">> => <<"venture_archived_v1">>,
      <<"venture_id">> => VentureId,
      <<"archived_by">> => <<"admin">>,
      <<"reason">> => <<"test cleanup">>,
      <<"archived_at">> => 2000}.

%% ===================================================================
%% Test suite with setup/teardown
%% ===================================================================

cqrs_integration_test_() ->
    {foreach,
     fun setup/0,
     fun teardown/1,
     [
      fun setup_projects_to_sqlite/1,
      fun query_venture_by_id_found/1,
      fun query_venture_by_id_not_found/1,
      fun archive_updates_status/1,
      fun get_ventures_page_returns_list/1,
      fun get_ventures_page_excludes_archived/1,
      fun get_ventures_page_includes_archived/1,
      fun get_ventures_page_limit_offset/1,
      fun projection_idempotency/1,
      fun full_cqrs_flow/1
     ]}.

setup() ->
    application:ensure_all_started(esqlite),
    DbPath = "/tmp/test_ventures_" ++
             integer_to_list(erlang:unique_integer([positive])) ++ ".db",
    {ok, _Pid} = test_store_proxy:start(DbPath),
    #{db_path => DbPath}.

teardown(#{}) ->
    test_store_proxy:stop(),
    ok.

%% ===================================================================
%% Test cases
%% ===================================================================

%% Projection inserts a row into ventures table
setup_projects_to_sqlite(#{}) ->
    fun() ->
        Event = setup_event(<<"vent-1">>),
        ok = venture_setup_v1_to_sqlite_ventures:project(Event),
        {ok, Rows} = query_ventures_store:query(
            "SELECT COUNT(*) FROM ventures WHERE venture_id = ?1", [<<"vent-1">>]),
        ?assertEqual(1, count_from_row(Rows))
    end.

%% Query by ID returns the projected venture with correct fields
query_venture_by_id_found(#{}) ->
    fun() ->
        ok = venture_setup_v1_to_sqlite_ventures:project(setup_event(<<"vent-qid">>)),
        {ok, Result} = get_venture_by_id:execute(<<"vent-qid">>),
        ?assertEqual(<<"vent-qid">>, maps:get(venture_id, Result)),
        ?assertEqual(<<"Test Venture">>, maps:get(name, Result)),
        ?assertEqual(<<"A test venture">>, maps:get(brief, Result)),
        ?assertEqual(?VENTURE_SETUP, maps:get(status, Result)),
        ?assertEqual([<<"repo1">>, <<"repo2">>], maps:get(repos, Result)),
        ?assertEqual([<<"erlang">>, <<"otp">>], maps:get(skills, Result)),
        ?assertEqual(#{<<"key">> => <<"value">>}, maps:get(context_map, Result)),
        ?assertEqual(1000, maps:get(initiated_at, Result)),
        ?assertEqual(<<"test@host">>, maps:get(initiated_by, Result))
    end.

%% Query by ID returns not_found for missing venture
query_venture_by_id_not_found(#{}) ->
    fun() ->
        ?assertEqual({error, not_found}, get_venture_by_id:execute(<<"nonexistent">>))
    end.

%% Archive projection sets ARCHIVED bit and updates status_label
archive_updates_status(#{}) ->
    fun() ->
        ok = venture_setup_v1_to_sqlite_ventures:project(setup_event(<<"vent-arch">>)),
        ok = venture_archived_v1_to_sqlite_ventures:project(archive_event(<<"vent-arch">>)),
        {ok, Result} = get_venture_by_id:execute(<<"vent-arch">>),
        Status = maps:get(status, Result),
        ?assertNotEqual(0, Status band ?VENTURE_ARCHIVED),
        ?assertNotEqual(0, Status band ?VENTURE_SETUP)
    end.

%% Page query returns list of ventures
get_ventures_page_returns_list(#{}) ->
    fun() ->
        ok = venture_setup_v1_to_sqlite_ventures:project(setup_event(<<"vent-p1">>)),
        E2 = (setup_event(<<"vent-p2">>))#{<<"name">> => <<"Second">>},
        ok = venture_setup_v1_to_sqlite_ventures:project(E2),
        {ok, Ventures} = get_ventures_page:execute(#{}),
        ?assertEqual(2, length(Ventures))
    end.

%% Page query excludes archived ventures by default
get_ventures_page_excludes_archived(#{}) ->
    fun() ->
        ok = venture_setup_v1_to_sqlite_ventures:project(setup_event(<<"vent-ea1">>)),
        E2 = (setup_event(<<"vent-ea2">>))#{<<"name">> => <<"ToArchive">>},
        ok = venture_setup_v1_to_sqlite_ventures:project(E2),
        ok = venture_archived_v1_to_sqlite_ventures:project(archive_event(<<"vent-ea2">>)),
        {ok, Ventures} = get_ventures_page:execute(#{}),
        ?assertEqual(1, length(Ventures)),
        [V] = Ventures,
        ?assertEqual(<<"vent-ea1">>, maps:get(venture_id, V))
    end.

%% Page query includes archived when requested
get_ventures_page_includes_archived(#{}) ->
    fun() ->
        ok = venture_setup_v1_to_sqlite_ventures:project(setup_event(<<"vent-ia1">>)),
        E2 = (setup_event(<<"vent-ia2">>))#{<<"name">> => <<"Archived">>},
        ok = venture_setup_v1_to_sqlite_ventures:project(E2),
        ok = venture_archived_v1_to_sqlite_ventures:project(archive_event(<<"vent-ia2">>)),
        {ok, Ventures} = get_ventures_page:execute(#{include_archived => true}),
        ?assertEqual(2, length(Ventures))
    end.

%% Page query supports limit and offset
get_ventures_page_limit_offset(#{}) ->
    fun() ->
        E1 = (setup_event(<<"vent-lo1">>))#{<<"initiated_at">> => 1000},
        E2 = (setup_event(<<"vent-lo2">>))#{<<"name">> => <<"V2">>, <<"initiated_at">> => 2000},
        E3 = (setup_event(<<"vent-lo3">>))#{<<"name">> => <<"V3">>, <<"initiated_at">> => 3000},
        ok = venture_setup_v1_to_sqlite_ventures:project(E1),
        ok = venture_setup_v1_to_sqlite_ventures:project(E2),
        ok = venture_setup_v1_to_sqlite_ventures:project(E3),
        %% Limit 1 -> only newest (3000, ORDER BY initiated_at DESC)
        {ok, [V1]} = get_ventures_page:execute(#{limit => 1}),
        ?assertEqual(<<"vent-lo3">>, maps:get(venture_id, V1)),
        %% Limit 1, offset 1 -> second newest (2000)
        {ok, [V2]} = get_ventures_page:execute(#{limit => 1, offset => 1}),
        ?assertEqual(<<"vent-lo2">>, maps:get(venture_id, V2)),
        %% Offset past all rows -> empty
        {ok, []} = get_ventures_page:execute(#{limit => 10, offset => 10})
    end.

%% Projecting same event twice is idempotent (INSERT OR REPLACE)
projection_idempotency(#{}) ->
    fun() ->
        Event = setup_event(<<"vent-idem">>),
        ok = venture_setup_v1_to_sqlite_ventures:project(Event),
        ok = venture_setup_v1_to_sqlite_ventures:project(Event),
        {ok, Rows} = query_ventures_store:query(
            "SELECT COUNT(*) FROM ventures WHERE venture_id = ?1", [<<"vent-idem">>]),
        ?assertEqual(1, count_from_row(Rows))
    end.

%% Full CQRS flow: command -> handler -> event -> projection -> query
full_cqrs_flow(#{}) ->
    fun() ->
        {ok, Cmd} = setup_venture_v1:from_map(#{
            <<"name">> => <<"Full Flow">>,
            <<"brief">> => <<"Testing complete flow">>,
            <<"initiated_by">> => <<"test@host">>
        }),
        {ok, [Event]} = maybe_setup_venture:handle(Cmd),
        EventMap = venture_setup_v1:to_map(Event),
        ok = venture_setup_v1_to_sqlite_ventures:project(EventMap),
        VentureId = maps:get(<<"venture_id">>, EventMap),
        {ok, Result} = get_venture_by_id:execute(VentureId),
        ?assertEqual(<<"Full Flow">>, maps:get(name, Result)),
        ?assertEqual(<<"Testing complete flow">>, maps:get(brief, Result)),
        ?assertEqual(?VENTURE_SETUP, maps:get(status, Result))
    end.

%% ===================================================================
%% Internal helpers
%% ===================================================================

%% esqlite3:fetchall returns [[N]] or [{N}] depending on the driver
count_from_row([[N]]) -> N;
count_from_row([{N}]) -> N.
