%%% @doc Layer 2b+2c: Handler + Aggregate execute/2 tests.
%%% Tests handle/1 business logic and execute/2 state machine guards.
%%% No I/O -- builds state via apply/2 chains, then tests commands.
-module(generate_division_handler_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("generate_division/include/generation_status.hrl").

%% Record field positions in generation_state
-define(F_DIVISION_ID,       2).
-define(F_STATUS,            3).
-define(F_GENERATED_MODULES, 4).
-define(F_GENERATED_TESTS,   5).

%% ===================================================================
%% Helpers: build state from event sequence
%% ===================================================================

fresh_state() ->
    {ok, S} = generation_aggregate:init(<<"any">>),
    S.

active_state() ->
    generation_aggregate:apply(fresh_state(), start_event_map()).

paused_state() ->
    generation_aggregate:apply(active_state(), pause_event_map()).

completed_state() ->
    generation_aggregate:apply(active_state(), complete_event_map()).

archived_state() ->
    generation_aggregate:apply(active_state(), archive_event_map()).

start_event_map() ->
    #{<<"event_type">> => <<"generation_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

pause_event_map() ->
    #{<<"event_type">> => <<"generation_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 2000,
      <<"reason">> => <<"review">>}.

complete_event_map() ->
    #{<<"event_type">> => <<"generation_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 4000}.

archive_event_map() ->
    #{<<"event_type">> => <<"generation_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 5000}.

%% ===================================================================
%% Layer 2b: Handler Tests (Business Logic)
%% ===================================================================

%% --- maybe_start_generation ---

handle_valid_start_test() ->
    {ok, Cmd} = start_generation_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_start_generation:handle(Cmd),
    Map = generation_started_v1:to_map(Event),
    ?assertEqual(<<"generation_started_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

handle_start_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 start_generation_v1:new(#{division_id => <<>>})).

%% --- maybe_generate_module ---

handle_valid_generate_module_test() ->
    {ok, Cmd} = generate_module_v1:new(#{
        division_id => <<"div-1">>,
        module_name => <<"my_module">>,
        module_type => <<"command">>,
        file_path => <<"src/my_module.erl">>,
        content => <<"-module(my_module).">>,
        description => <<"A module">>,
        generated_by => <<"hecate">>
    }),
    {ok, [Event]} = maybe_generate_module:handle(Cmd, #{}),
    Map = module_generated_v1:to_map(Event),
    ?assertEqual(<<"module_generated_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"my_module">>, maps:get(<<"module_name">>, Map)),
    ?assertEqual(<<"command">>, maps:get(<<"module_type">>, Map)).

handle_generate_module_duplicate_test() ->
    {ok, Cmd} = generate_module_v1:new(#{
        division_id => <<"div-1">>,
        module_name => <<"existing_mod">>
    }),
    Context = #{generated_modules => #{<<"existing_mod">> => #{}}},
    ?assertEqual({error, module_already_generated},
                 maybe_generate_module:handle(Cmd, Context)).

handle_generate_module_empty_context_test() ->
    {ok, Cmd} = generate_module_v1:new(#{
        division_id => <<"div-1">>,
        module_name => <<"new_mod">>
    }),
    {ok, [_Event]} = maybe_generate_module:handle(Cmd, #{}).

handle_generate_module_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 generate_module_v1:new(#{division_id => <<>>, module_name => <<"m">>})).

handle_generate_module_invalid_module_name_test() ->
    ?assertEqual({error, {invalid_field, module_name}},
                 generate_module_v1:new(#{division_id => <<"d">>, module_name => <<>>})).

%% --- maybe_generate_test ---

handle_valid_generate_test_test() ->
    {ok, Cmd} = generate_test_v1:new(#{
        division_id => <<"div-1">>,
        test_name => <<"my_tests">>,
        test_type => <<"unit">>,
        module_name => <<"my_module">>,
        file_path => <<"test/my_tests.erl">>,
        content => <<"-module(my_tests).">>,
        description => <<"Unit tests">>,
        generated_by => <<"hecate">>
    }),
    {ok, [Event]} = maybe_generate_test:handle(Cmd, #{}),
    Map = test_generated_v1:to_map(Event),
    ?assertEqual(<<"test_generated_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"my_tests">>, maps:get(<<"test_name">>, Map)),
    ?assertEqual(<<"unit">>, maps:get(<<"test_type">>, Map)).

handle_generate_test_duplicate_test() ->
    {ok, Cmd} = generate_test_v1:new(#{
        division_id => <<"div-1">>,
        test_name => <<"existing_test">>
    }),
    Context = #{generated_tests => #{<<"existing_test">> => #{}}},
    ?assertEqual({error, {duplicate_test_name, <<"existing_test">>}},
                 maybe_generate_test:handle(Cmd, Context)).

handle_generate_test_empty_context_test() ->
    {ok, Cmd} = generate_test_v1:new(#{
        division_id => <<"div-1">>,
        test_name => <<"new_test">>
    }),
    {ok, [_Event]} = maybe_generate_test:handle(Cmd, #{}).

handle_generate_test_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 generate_test_v1:new(#{division_id => <<>>, test_name => <<"t">>})).

handle_generate_test_invalid_test_name_test() ->
    ?assertEqual({error, {invalid_field, test_name}},
                 generate_test_v1:new(#{division_id => <<"d">>, test_name => <<>>})).

%% --- maybe_pause_generation ---

handle_valid_pause_test() ->
    {ok, Cmd} = pause_generation_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"need review">>
    }),
    {ok, [Event]} = maybe_pause_generation:handle(Cmd),
    Map = generation_paused_v1:to_map(Event),
    ?assertEqual(<<"generation_paused_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"need review">>, maps:get(<<"reason">>, Map)).

handle_pause_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 pause_generation_v1:new(#{division_id => <<>>})).

%% --- maybe_resume_generation ---

handle_valid_resume_test() ->
    {ok, Cmd} = resume_generation_v1:new(#{division_id => <<"div-1">>}),
    {ok, [Event]} = maybe_resume_generation:handle(Cmd),
    Map = generation_resumed_v1:to_map(Event),
    ?assertEqual(<<"generation_resumed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

handle_resume_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 resume_generation_v1:new(#{division_id => <<>>})).

%% --- maybe_complete_generation ---

handle_valid_complete_test() ->
    {ok, Cmd} = complete_generation_v1:new(#{division_id => <<"div-1">>}),
    {ok, [Event]} = maybe_complete_generation:handle(Cmd),
    Map = generation_completed_v1:to_map(Event),
    ?assertEqual(<<"generation_completed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

handle_complete_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 complete_generation_v1:new(#{division_id => <<>>})).

%% --- maybe_archive_generation ---

handle_valid_archive_test() ->
    {ok, Cmd} = archive_generation_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    {ok, [Event]} = maybe_archive_generation:handle(Cmd),
    Map = generation_archived_v1:to_map(Event),
    ?assertEqual(<<"generation_archived_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)).

handle_archive_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 archive_generation_v1:new(#{division_id => <<>>})).

%% ===================================================================
%% Layer 2c: Aggregate execute/2 State Machine Tests
%% ===================================================================

%% --- start_generation command ---

execute_start_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"start_generation">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = generation_aggregate:execute(fresh_state(), Cmd),
    ?assertEqual(<<"generation_started_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_start_not_allowed_after_start_test() ->
    Cmd = #{<<"command_type">> => <<"start_generation">>,
            <<"division_id">> => <<"div-2">>},
    %% After start, status has INITIATED+ACTIVE set, so this goes through
    %% the second clause which routes to execute_lifecycle, which won't
    %% match start_generation and returns unknown_command
    ?assertMatch({error, _}, generation_aggregate:execute(active_state(), Cmd)).

%% --- generate_module command ---

execute_generate_module_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"generate_module">>,
            <<"division_id">> => <<"div-1">>,
            <<"module_name">> => <<"new_mod">>,
            <<"module_type">> => <<"aggregate">>,
            <<"file_path">> => <<"src/new_mod.erl">>,
            <<"content">> => <<"-module(new_mod).">>,
            <<"description">> => <<"An aggregate">>},
    {ok, [EventMap]} = generation_aggregate:execute(active_state(), Cmd),
    ?assertEqual(<<"module_generated_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_generate_module_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"generate_module">>,
            <<"division_id">> => <<"div-1">>,
            <<"module_name">> => <<"mod">>},
    ?assertMatch({error, {not_active, _}},
                 generation_aggregate:execute(paused_state(), Cmd)).

execute_generate_module_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"generate_module">>,
            <<"division_id">> => <<"div-1">>,
            <<"module_name">> => <<"mod">>},
    ?assertEqual({error, generation_not_started},
                 generation_aggregate:execute(fresh_state(), Cmd)).

execute_generate_module_on_completed_state_test() ->
    Cmd = #{<<"command_type">> => <<"generate_module">>,
            <<"division_id">> => <<"div-1">>,
            <<"module_name">> => <<"mod">>},
    ?assertMatch({error, {not_active, _}},
                 generation_aggregate:execute(completed_state(), Cmd)).

%% --- generate_test command ---

execute_generate_test_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"generate_test">>,
            <<"division_id">> => <<"div-1">>,
            <<"test_name">> => <<"my_test">>,
            <<"test_type">> => <<"unit">>,
            <<"module_name">> => <<"my_module">>},
    {ok, [EventMap]} = generation_aggregate:execute(active_state(), Cmd),
    ?assertEqual(<<"test_generated_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_generate_test_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"generate_test">>,
            <<"division_id">> => <<"div-1">>,
            <<"test_name">> => <<"test">>},
    ?assertMatch({error, {not_active, _}},
                 generation_aggregate:execute(paused_state(), Cmd)).

execute_generate_test_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"generate_test">>,
            <<"division_id">> => <<"div-1">>,
            <<"test_name">> => <<"test">>},
    ?assertEqual({error, generation_not_started},
                 generation_aggregate:execute(fresh_state(), Cmd)).

%% --- pause_generation command ---

execute_pause_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"pause_generation">>,
            <<"division_id">> => <<"div-1">>,
            <<"reason">> => <<"need review">>},
    {ok, [EventMap]} = generation_aggregate:execute(active_state(), Cmd),
    ?assertEqual(<<"generation_paused_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_pause_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"pause_generation">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 generation_aggregate:execute(paused_state(), Cmd)).

execute_pause_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"pause_generation">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, generation_not_started},
                 generation_aggregate:execute(fresh_state(), Cmd)).

%% --- resume_generation command ---

execute_resume_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"resume_generation">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = generation_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"generation_resumed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_resume_not_paused_test() ->
    Cmd = #{<<"command_type">> => <<"resume_generation">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_paused, _}},
                 generation_aggregate:execute(active_state(), Cmd)).

execute_resume_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"resume_generation">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, generation_not_started},
                 generation_aggregate:execute(fresh_state(), Cmd)).

%% --- complete_generation command ---

execute_complete_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"complete_generation">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = generation_aggregate:execute(active_state(), Cmd),
    ?assertEqual(<<"generation_completed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_complete_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"complete_generation">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 generation_aggregate:execute(paused_state(), Cmd)).

execute_complete_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"complete_generation">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, generation_not_started},
                 generation_aggregate:execute(fresh_state(), Cmd)).

%% --- archive_generation command ---

execute_archive_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_generation">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = generation_aggregate:execute(active_state(), Cmd),
    ?assertEqual(<<"generation_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_generation">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = generation_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"generation_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_on_completed_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_generation">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = generation_aggregate:execute(completed_state(), Cmd),
    ?assertEqual(<<"generation_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_not_found_test() ->
    Cmd = #{<<"command_type">> => <<"archive_generation">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, generation_not_started},
                 generation_aggregate:execute(fresh_state(), Cmd)).

execute_archive_already_archived_test() ->
    Cmd = #{<<"command_type">> => <<"archive_generation">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, generation_archived},
                 generation_aggregate:execute(archived_state(), Cmd)).

%% --- unknown command ---

execute_unknown_command_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, generation_not_started},
                 generation_aggregate:execute(fresh_state(), Cmd)).

execute_unknown_command_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, unknown_command},
                 generation_aggregate:execute(active_state(), Cmd)).

execute_missing_command_type_test() ->
    ?assertEqual({error, generation_not_started},
                 generation_aggregate:execute(fresh_state(), #{<<"data">> => <<"stuff">>})).

%% --- evoq callback order: execute(State, Payload) ---

execute_evoq_callback_order_test() ->
    State = fresh_state(),
    Payload = #{<<"command_type">> => <<"start_generation">>,
                <<"division_id">> => <<"div-order">>},
    %% Correct order: State first, Payload second
    {ok, _Events} = generation_aggregate:execute(State, Payload).

%% --- generate_module passes generated_modules context ---

execute_generate_module_duplicate_via_aggregate_test() ->
    %% Start, then generate a module, then try to generate same name again
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event_map()),
    ModEvent = #{<<"event_type">> => <<"module_generated_v1">>,
                 <<"division_id">> => <<"div-1">>,
                 <<"module_id">> => <<"mod-001">>,
                 <<"module_name">> => <<"existing_mod">>,
                 <<"module_type">> => <<"command">>,
                 <<"file_path">> => <<"src/existing_mod.erl">>,
                 <<"content">> => <<"-module(existing_mod).">>,
                 <<"generated_at">> => 2000},
    S2 = generation_aggregate:apply(S1, ModEvent),
    Cmd = #{<<"command_type">> => <<"generate_module">>,
            <<"division_id">> => <<"div-1">>,
            <<"module_name">> => <<"existing_mod">>},
    ?assertEqual({error, module_already_generated},
                 generation_aggregate:execute(S2, Cmd)).

%% --- generate_test passes generated_tests context ---

execute_generate_test_duplicate_via_aggregate_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event_map()),
    TestEvent = #{<<"event_type">> => <<"test_generated_v1">>,
                  <<"division_id">> => <<"div-1">>,
                  <<"test_id">> => <<"tst-001">>,
                  <<"test_name">> => <<"existing_test">>,
                  <<"test_type">> => <<"unit">>,
                  <<"module_name">> => <<"mod">>,
                  <<"file_path">> => <<"test/existing_test.erl">>,
                  <<"content">> => <<"-module(existing_test).">>,
                  <<"generated_at">> => 3000},
    S2 = generation_aggregate:apply(S1, TestEvent),
    Cmd = #{<<"command_type">> => <<"generate_test">>,
            <<"division_id">> => <<"div-1">>,
            <<"test_name">> => <<"existing_test">>},
    ?assertEqual({error, {duplicate_test_name, <<"existing_test">>}},
                 generation_aggregate:execute(S2, Cmd)).

%% --- archived state rejects all commands ---

execute_all_commands_rejected_on_archived_test() ->
    S = archived_state(),
    ?assertEqual({error, generation_archived},
                 generation_aggregate:execute(S,
                     #{<<"command_type">> => <<"generate_module">>,
                       <<"division_id">> => <<"div-1">>,
                       <<"module_name">> => <<"m">>})),
    ?assertEqual({error, generation_archived},
                 generation_aggregate:execute(S,
                     #{<<"command_type">> => <<"pause_generation">>,
                       <<"division_id">> => <<"div-1">>})),
    ?assertEqual({error, generation_archived},
                 generation_aggregate:execute(S,
                     #{<<"command_type">> => <<"resume_generation">>,
                       <<"division_id">> => <<"div-1">>})),
    ?assertEqual({error, generation_archived},
                 generation_aggregate:execute(S,
                     #{<<"command_type">> => <<"complete_generation">>,
                       <<"division_id">> => <<"div-1">>})),
    ?assertEqual({error, generation_archived},
                 generation_aggregate:execute(S,
                     #{<<"command_type">> => <<"archive_generation">>,
                       <<"division_id">> => <<"div-1">>})).
