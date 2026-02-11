%%% @doc Layer 4b: ReckonDB Dispatch Tests — test_division.
%%% Verifies that dispatch/1 persists events to ReckonDB and that
%%% they can be read back with correct data.
-module(test_division_dispatch_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_db/include/reckon_db.hrl").

dispatch_test_() ->
    {setup, fun start_infra/0, fun stop_infra/1, [
        fun dispatch_persists_event/0,
        fun dispatch_returns_version_and_events/0,
        fun dispatch_second_command_appends_to_stream/0,
        fun read_back_event_data_matches/0
    ]}.

start_infra() ->
    application:ensure_all_started(reckon_db),
    application:ensure_all_started(evoq),
    application:set_env(evoq, event_store_adapter, reckon_evoq_adapter),
    TmpDir = "/tmp/test_dispatch_testing_" ++
        integer_to_list(erlang:unique_integer([positive])),
    StoreConfig = #store_config{
        store_id = test_division_store,
        data_dir = TmpDir,
        mode = single,
        options = #{}
    },
    {ok, _} = reckon_db_sup:start_store(StoreConfig),
    #{tmp_dir => TmpDir}.

stop_infra(#{tmp_dir := TmpDir}) ->
    reckon_db_sup:stop_store(test_division_store),
    os:cmd("rm -rf " ++ TmpDir),
    ok.

dispatch_persists_event() ->
    DivisionId = unique_id(<<"test-persist">>),
    {ok, Cmd} = start_testing_v1:new(#{division_id => DivisionId}),
    {ok, _, [_]} = maybe_start_testing:dispatch(Cmd),
    {ok, Events} = esdb_gater_api:get_events(
        test_division_store, DivisionId, 0, 100, forward),
    ?assertEqual(1, length(Events)).

dispatch_returns_version_and_events() ->
    DivisionId = unique_id(<<"test-ret">>),
    {ok, Cmd} = start_testing_v1:new(#{division_id => DivisionId}),
    {ok, Version, EventMaps} = maybe_start_testing:dispatch(Cmd),
    ?assert(is_integer(Version)),
    ?assert(is_list(EventMaps)),
    ?assertEqual(1, length(EventMaps)),
    [E] = EventMaps,
    ?assert(is_map(E)).

dispatch_second_command_appends_to_stream() ->
    DivisionId = unique_id(<<"test-stream">>),
    {ok, StartCmd} = start_testing_v1:new(#{division_id => DivisionId}),
    {ok, _, _} = maybe_start_testing:dispatch(StartCmd),
    {ok, ArchiveCmd} = archive_testing_v1:new(#{division_id => DivisionId}),
    {ok, _, _} = maybe_archive_testing:dispatch(ArchiveCmd),
    {ok, Events} = esdb_gater_api:get_events(
        test_division_store, DivisionId, 0, 100, forward),
    ?assertEqual(2, length(Events)).

read_back_event_data_matches() ->
    DivisionId = unique_id(<<"test-read">>),
    {ok, Cmd} = start_testing_v1:new(#{
        division_id => DivisionId,
        started_by => <<"test@host">>
    }),
    {ok, _, _} = maybe_start_testing:dispatch(Cmd),
    {ok, [Event | _]} = esdb_gater_api:get_events(
        test_division_store, DivisionId, 0, 100, forward),
    Data = extract_data(Event),
    Id = maps:get(<<"division_id">>, Data,
        maps:get(division_id, Data, undefined)),
    ?assertEqual(DivisionId, Id).

unique_id(Prefix) ->
    <<Prefix/binary, "-",
      (integer_to_binary(erlang:unique_integer([positive])))/binary>>.

extract_data(Event) when is_record(Event, event) ->
    Event#event.data;
extract_data(#{data := D}) when is_map(D) ->
    D;
extract_data(#{<<"data">> := D}) when is_map(D) ->
    D;
extract_data(Event) when is_map(Event) ->
    Event.
