%%% @doc Layer 2b+2c: Handler + Aggregate execute/2 tests.
%%% Tests handle/1 and handle/2 business logic, and execute/2 state
%%% machine guards. No I/O -- builds state via apply/2 chains, then
%%% tests commands against those states.
-module(discover_divisions_handler_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("discover_divisions/include/discovery_status.hrl").

%% ===================================================================
%% Helpers: build state from event sequence
%% ===================================================================

fresh_state() ->
    {ok, S} = discovery_aggregate:init(<<"any-id">>),
    S.

started_state() ->
    discovery_aggregate:apply(fresh_state(), start_event_map()).

active_with_division_state() ->
    discovery_aggregate:apply(started_state(), discover_event_map()).

paused_state() ->
    discovery_aggregate:apply(started_state(), pause_event_map()).

completed_state() ->
    discovery_aggregate:apply(started_state(), complete_event_map()).

archived_state() ->
    discovery_aggregate:apply(started_state(), archive_event_map()).

%% ===================================================================
%% Event map fixtures (for building aggregate state)
%% ===================================================================

start_event_map() ->
    #{<<"event_type">> => <<"discovery_started_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

discover_event_map() ->
    #{<<"event_type">> => <<"division_discovered_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"division_id">> => <<"div-1">>,
      <<"context_name">> => <<"auth">>,
      <<"description">> => <<"Auth context">>,
      <<"identified_by">> => <<"user@host">>,
      <<"discovered_at">> => 2000}.

pause_event_map() ->
    #{<<"event_type">> => <<"discovery_paused_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"paused_at">> => 3000,
      <<"reason">> => <<"review">>}.

complete_event_map() ->
    #{<<"event_type">> => <<"discovery_completed_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"completed_at">> => 5000}.

archive_event_map() ->
    #{<<"event_type">> => <<"discovery_archived_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"archived_at">> => 6000,
      <<"archived_by">> => <<"admin">>,
      <<"reason">> => <<"done">>}.

%% ===================================================================
%% Layer 2b: Handler Tests (Business Logic)
%% ===================================================================

%% --- maybe_start_discovery ---

handle_start_discovery_test() ->
    {ok, Cmd} = start_discovery_v1:new(#{
        venture_id => <<"vent-1">>,
        started_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_start_discovery:handle(Cmd),
    Map = discovery_started_v1:to_map(Event),
    ?assertEqual(<<"discovery_started_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)).

handle_start_discovery_with_context_test() ->
    {ok, Cmd} = start_discovery_v1:new(#{venture_id => <<"vent-1">>}),
    {ok, [_Event]} = maybe_start_discovery:handle(Cmd, #{}).

%% --- maybe_discover_division ---

handle_discover_division_test() ->
    {ok, Cmd} = discover_division_v1:new(#{
        venture_id => <<"vent-1">>,
        context_name => <<"auth">>,
        description => <<"Auth context">>,
        identified_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_discover_division:handle(Cmd, #{discovered_divisions => #{}}),
    Map = division_discovered_v1:to_map(Event),
    ?assertEqual(<<"division_discovered_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"auth">>, maps:get(<<"context_name">>, Map)).

handle_discover_division_already_discovered_test() ->
    {ok, Cmd} = discover_division_v1:new(#{
        venture_id => <<"vent-1">>,
        context_name => <<"auth">>
    }),
    Context = #{discovered_divisions => #{<<"auth">> => <<"div-1">>}},
    ?assertEqual({error, division_already_discovered},
                 maybe_discover_division:handle(Cmd, Context)).

handle_discover_division_no_context_test() ->
    {ok, Cmd} = discover_division_v1:new(#{
        venture_id => <<"vent-1">>,
        context_name => <<"payments">>
    }),
    %% handle/1 defaults to empty context
    {ok, [_Event]} = maybe_discover_division:handle(Cmd).

%% --- maybe_pause_discovery ---

handle_pause_discovery_test() ->
    {ok, Cmd} = pause_discovery_v1:new(#{
        venture_id => <<"vent-1">>,
        reason => <<"needs review">>
    }),
    {ok, [Event]} = maybe_pause_discovery:handle(Cmd),
    Map = discovery_paused_v1:to_map(Event),
    ?assertEqual(<<"discovery_paused_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"needs review">>, maps:get(<<"reason">>, Map)).

%% --- maybe_resume_discovery ---

handle_resume_discovery_test() ->
    {ok, Cmd} = resume_discovery_v1:new(#{venture_id => <<"vent-1">>}),
    {ok, [Event]} = maybe_resume_discovery:handle(Cmd),
    Map = discovery_resumed_v1:to_map(Event),
    ?assertEqual(<<"discovery_resumed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)).

%% --- maybe_complete_discovery ---

handle_complete_discovery_test() ->
    {ok, Cmd} = complete_discovery_v1:new(#{venture_id => <<"vent-1">>}),
    {ok, [Event]} = maybe_complete_discovery:handle(Cmd),
    Map = discovery_completed_v1:to_map(Event),
    ?assertEqual(<<"discovery_completed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)).

%% --- maybe_archive_discovery ---

handle_archive_discovery_test() ->
    {ok, Cmd} = archive_discovery_v1:new(#{
        venture_id => <<"vent-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    {ok, [Event]} = maybe_archive_discovery:handle(Cmd),
    Map = discovery_archived_v1:to_map(Event),
    ?assertEqual(<<"discovery_archived_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)).

%% ===================================================================
%% Layer 2c: Aggregate execute/2 State Machine Tests
%% ===================================================================

%% --- start_discovery command ---

execute_start_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"start_discovery">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"started_by">> => <<"user@host">>},
    {ok, [EventMap]} = discovery_aggregate:execute(fresh_state(), Cmd),
    ?assertEqual(<<"discovery_started_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_start_already_started_test() ->
    Cmd = #{<<"command_type">> => <<"start_discovery">>,
            <<"venture_id">> => <<"vent-2">>},
    %% Already started: any command on initiated state goes through
    %% execute_lifecycle, and start_discovery is not a lifecycle command
    ?assertEqual({error, unknown_command},
                 discovery_aggregate:execute(started_state(), Cmd)).

%% --- discover_division command ---

execute_discover_division_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"discover_division">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"context_name">> => <<"billing">>,
            <<"description">> => <<"Billing context">>},
    {ok, [EventMap]} = discovery_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"division_discovered_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_discover_division_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"discover_division">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"context_name">> => <<"billing">>},
    ?assertEqual({error, discovery_not_started},
                 discovery_aggregate:execute(fresh_state(), Cmd)).

execute_discover_division_not_active_paused_test() ->
    S = paused_state(),
    Cmd = #{<<"command_type">> => <<"discover_division">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"context_name">> => <<"billing">>},
    {error, {not_active, _Status}} = discovery_aggregate:execute(S, Cmd).

execute_discover_division_not_active_completed_test() ->
    S = completed_state(),
    Cmd = #{<<"command_type">> => <<"discover_division">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"context_name">> => <<"billing">>},
    {error, {not_active, _Status}} = discovery_aggregate:execute(S, Cmd).

execute_discover_division_duplicate_context_test() ->
    S = active_with_division_state(),
    Cmd = #{<<"command_type">> => <<"discover_division">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"context_name">> => <<"auth">>},
    ?assertEqual({error, division_already_discovered},
                 discovery_aggregate:execute(S, Cmd)).

%% --- pause_discovery command ---

execute_pause_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"pause_discovery">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"reason">> => <<"needs review">>},
    {ok, [EventMap]} = discovery_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"discovery_paused_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_pause_not_active_test() ->
    S = paused_state(),
    Cmd = #{<<"command_type">> => <<"pause_discovery">>,
            <<"venture_id">> => <<"vent-1">>},
    {error, {not_active, _Status}} = discovery_aggregate:execute(S, Cmd).

%% --- resume_discovery command ---

execute_resume_on_paused_test() ->
    S = paused_state(),
    Cmd = #{<<"command_type">> => <<"resume_discovery">>,
            <<"venture_id">> => <<"vent-1">>},
    {ok, [EventMap]} = discovery_aggregate:execute(S, Cmd),
    ?assertEqual(<<"discovery_resumed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_resume_not_paused_test() ->
    Cmd = #{<<"command_type">> => <<"resume_discovery">>,
            <<"venture_id">> => <<"vent-1">>},
    {error, {not_paused, _Status}} = discovery_aggregate:execute(started_state(), Cmd).

%% --- complete_discovery command ---

execute_complete_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"complete_discovery">>,
            <<"venture_id">> => <<"vent-1">>},
    {ok, [EventMap]} = discovery_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"discovery_completed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_complete_not_active_test() ->
    S = paused_state(),
    Cmd = #{<<"command_type">> => <<"complete_discovery">>,
            <<"venture_id">> => <<"vent-1">>},
    {error, {not_active, _Status}} = discovery_aggregate:execute(S, Cmd).

%% --- archive_discovery command ---

execute_archive_on_started_test() ->
    Cmd = #{<<"command_type">> => <<"archive_discovery">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"archived_by">> => <<"admin">>,
            <<"reason">> => <<"cleanup">>},
    {ok, [EventMap]} = discovery_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"discovery_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_already_archived_test() ->
    S = archived_state(),
    Cmd = #{<<"command_type">> => <<"archive_discovery">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, discovery_archived},
                 discovery_aggregate:execute(S, Cmd)).

execute_archive_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"archive_discovery">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, discovery_not_started},
                 discovery_aggregate:execute(fresh_state(), Cmd)).

%% Archive from completed state (should work -- initiated and not archived)
execute_archive_after_complete_test() ->
    S = completed_state(),
    Cmd = #{<<"command_type">> => <<"archive_discovery">>,
            <<"venture_id">> => <<"vent-1">>},
    {ok, [EventMap]} = discovery_aggregate:execute(S, Cmd),
    ?assertEqual(<<"discovery_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

%% --- unknown command ---

execute_unknown_command_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, discovery_not_started},
                 discovery_aggregate:execute(fresh_state(), Cmd)).

execute_unknown_command_on_started_test() ->
    Cmd = #{<<"command_type">> => <<"nonexistent">>},
    ?assertEqual({error, unknown_command},
                 discovery_aggregate:execute(started_state(), Cmd)).

execute_missing_command_type_test() ->
    ?assertEqual({error, discovery_not_started},
                 discovery_aggregate:execute(fresh_state(), #{<<"data">> => <<"stuff">>})).

%% --- evoq callback order: execute(State, Payload) ---

execute_evoq_callback_order_test() ->
    State = fresh_state(),
    Payload = #{<<"command_type">> => <<"start_discovery">>,
                <<"venture_id">> => <<"vent-order">>},
    %% Correct order: State first, Payload second
    {ok, _Events} = discovery_aggregate:execute(State, Payload).
