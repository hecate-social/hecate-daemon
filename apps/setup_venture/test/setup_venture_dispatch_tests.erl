%%% @doc Layer 4b: ReckonDB Dispatch Tests — setup_venture.
%%% Verifies that dispatch/1 persists events to ReckonDB and that
%%% they can be read back with correct data.
-module(setup_venture_dispatch_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_db/include/reckon_db.hrl").

%% ===================================================================
%% Test suite with ReckonDB + evoq infrastructure
%% ===================================================================

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
    TmpDir = "/tmp/test_dispatch_setup_" ++
        integer_to_list(erlang:unique_integer([positive])),
    StoreConfig = #store_config{
        store_id = setup_venture_store,
        data_dir = TmpDir,
        mode = single,
        options = #{}
    },
    {ok, _} = reckon_db_sup:start_store(StoreConfig),
    #{tmp_dir => TmpDir}.

stop_infra(#{tmp_dir := TmpDir}) ->
    reckon_db_sup:stop_store(setup_venture_store),
    os:cmd("rm -rf " ++ TmpDir),
    ok.

%% ===================================================================
%% Test cases
%% ===================================================================

%% Dispatch persists exactly one event to ReckonDB
dispatch_persists_event() ->
    {ok, Cmd} = setup_venture_v1:new(#{name => <<"Dispatch Persist Test">>}),
    VentureId = setup_venture_v1:get_venture_id(Cmd),
    {ok, _Version, [_Event]} = maybe_setup_venture:dispatch(Cmd),
    {ok, Events} = esdb_gater_api:get_events(
        setup_venture_store, VentureId, 0, 100, forward),
    ?assertEqual(1, length(Events)).

%% Dispatch returns {ok, Version, [EventMaps]}
dispatch_returns_version_and_events() ->
    {ok, Cmd} = setup_venture_v1:new(#{name => <<"Return Type Test">>}),
    {ok, Version, EventMaps} = maybe_setup_venture:dispatch(Cmd),
    ?assert(is_integer(Version)),
    ?assert(is_list(EventMaps)),
    ?assertEqual(1, length(EventMaps)),
    [E] = EventMaps,
    ?assert(is_map(E)).

%% Second dispatch to same aggregate produces two events in store
dispatch_second_command_appends_to_stream() ->
    VentureId = <<"vent-incr-",
        (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    {ok, SetupCmd} = setup_venture_v1:new(#{
        venture_id => VentureId,
        name => <<"Version Incr Test">>
    }),
    {ok, _, _} = maybe_setup_venture:dispatch(SetupCmd),
    {ok, RefineCmd} = refine_vision_v1:new(#{
        venture_id => VentureId,
        brief => <<"Updated brief">>
    }),
    {ok, _, _} = maybe_refine_vision:dispatch(RefineCmd),
    %% Verify two events in the stream
    {ok, Events} = esdb_gater_api:get_events(
        setup_venture_store, VentureId, 0, 100, forward),
    ?assertEqual(2, length(Events)).

%% Read-back event data matches the dispatched command
read_back_event_data_matches() ->
    {ok, Cmd} = setup_venture_v1:new(#{
        name => <<"ReadBack Test">>,
        brief => <<"Verify data">>,
        initiated_by => <<"test@host">>
    }),
    VentureId = setup_venture_v1:get_venture_id(Cmd),
    {ok, _, _} = maybe_setup_venture:dispatch(Cmd),
    {ok, [Event | _]} = esdb_gater_api:get_events(
        setup_venture_store, VentureId, 0, 100, forward),
    Data = extract_data(Event),
    Name = maps:get(<<"name">>, Data,
        maps:get(name, Data, undefined)),
    ?assertEqual(<<"ReadBack Test">>, Name).

%% ===================================================================
%% Internal helpers
%% ===================================================================

extract_data(Event) when is_record(Event, event) ->
    Event#event.data;
extract_data(#{data := D}) when is_map(D) ->
    D;
extract_data(#{<<"data">> := D}) when is_map(D) ->
    D;
extract_data(Event) when is_map(Event) ->
    Event.
