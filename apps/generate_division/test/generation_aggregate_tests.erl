%%% @doc Layer 1: Dossier Tests -- Pure aggregate state reconstruction.
%%% Tests apply/2 chains to verify the dossier (aggregate state)
%%% reconstructs correctly from event sequences. No processes, no I/O.
%%%
%%% Since generation_state record is internal to generation_aggregate,
%%% we verify state correctness through execute/2 behavior (state machine
%%% guards) and through the behaviour callback apply/2.
-module(generation_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("generate_division/include/generation_status.hrl").

%% Record field positions in generation_state (record tag is element 1)
-define(F_DIVISION_ID,       2).
-define(F_STATUS,            3).
-define(F_GENERATED_MODULES, 4).
-define(F_GENERATED_TESTS,   5).
-define(F_STARTED_AT,        6).
-define(F_PAUSED_AT,         7).
-define(F_COMPLETED_AT,      8).
-define(F_PAUSE_REASON,      9).

%% ===================================================================
%% Test Fixtures (reusable event maps)
%% ===================================================================

start_event() ->
    #{<<"event_type">> => <<"generation_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

module_generated_event() ->
    #{<<"event_type">> => <<"module_generated_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"module_id">> => <<"mod-001">>,
      <<"module_name">> => <<"my_module">>,
      <<"module_type">> => <<"command">>,
      <<"file_path">> => <<"src/my_module.erl">>,
      <<"content">> => <<"-module(my_module).">>,
      <<"description">> => <<"A test module">>,
      <<"generated_by">> => <<"hecate">>,
      <<"generated_at">> => 2000}.

test_generated_event() ->
    #{<<"event_type">> => <<"test_generated_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"test_id">> => <<"tst-001">>,
      <<"test_name">> => <<"my_module_tests">>,
      <<"test_type">> => <<"unit">>,
      <<"module_name">> => <<"my_module">>,
      <<"file_path">> => <<"test/my_module_tests.erl">>,
      <<"content">> => <<"-module(my_module_tests).">>,
      <<"description">> => <<"Tests for my_module">>,
      <<"generated_by">> => <<"hecate">>,
      <<"generated_at">> => 3000}.

pause_event() ->
    #{<<"event_type">> => <<"generation_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"waiting for review">>}.

resume_event() ->
    #{<<"event_type">> => <<"generation_resumed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"resumed_at">> => 5000}.

complete_event() ->
    #{<<"event_type">> => <<"generation_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event() ->
    #{<<"event_type">> => <<"generation_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000,
      <<"archived_by">> => <<"admin">>,
      <<"reason">> => <<"cleanup">>}.

%% ===================================================================
%% Helpers
%% ===================================================================

fresh_state() ->
    {ok, S} = generation_aggregate:init(<<"any">>),
    S.

%% ===================================================================
%% Layer 1 Tests: Dossier (Pure Aggregate State)
%% ===================================================================

%% initial_state via init/1 returns zeroed state
initial_state_test() ->
    S = fresh_state(),
    ?assertEqual(undefined, element(?F_DIVISION_ID, S)),
    ?assertEqual(0, element(?F_STATUS, S)),
    ?assertEqual(#{}, element(?F_GENERATED_MODULES, S)),
    ?assertEqual(#{}, element(?F_GENERATED_TESTS, S)),
    ?assertEqual(undefined, element(?F_STARTED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S)),
    ?assertEqual(undefined, element(?F_COMPLETED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S)).

%% init/1 callback returns {ok, State}
init_callback_test() ->
    {ok, S} = generation_aggregate:init(<<"div-1">>),
    ?assertEqual(0, element(?F_STATUS, S)).

%% Apply generation_started_v1 populates division_id, status, started_at
apply_start_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    Status = element(?F_STATUS, S1),
    ?assertNotEqual(0, Status band ?GENERATION_INITIATED),
    ?assertNotEqual(0, Status band ?GENERATION_ACTIVE),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)),
    ?assertEqual(1000, element(?F_STARTED_AT, S1)).

%% Apply module_generated_v1 adds to generated_modules map
apply_module_generated_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    S2 = generation_aggregate:apply(S1, module_generated_event()),
    Modules = element(?F_GENERATED_MODULES, S2),
    ?assert(maps:is_key(<<"my_module">>, Modules)),
    Details = maps:get(<<"my_module">>, Modules),
    ?assertEqual(<<"my_module">>, maps:get(module_name, Details)),
    ?assertEqual(2000, maps:get(generated_at, Details)).

%% Apply test_generated_v1 adds to generated_tests map
apply_test_generated_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    S2 = generation_aggregate:apply(S1, test_generated_event()),
    Tests = element(?F_GENERATED_TESTS, S2),
    ?assert(maps:is_key(<<"my_module_tests">>, Tests)),
    Details = maps:get(<<"my_module_tests">>, Tests),
    ?assertEqual(<<"my_module_tests">>, maps:get(test_name, Details)),
    ?assertEqual(3000, maps:get(generated_at, Details)).

%% Apply generation_paused_v1 sets PAUSED, clears ACTIVE
apply_pause_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    S2 = generation_aggregate:apply(S1, pause_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?GENERATION_PAUSED),
    ?assertEqual(0, Status band ?GENERATION_ACTIVE),
    ?assertEqual(4000, element(?F_PAUSED_AT, S2)),
    ?assertEqual(<<"waiting for review">>, element(?F_PAUSE_REASON, S2)).

%% Apply generation_resumed_v1 clears PAUSED, sets ACTIVE
apply_resume_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    S2 = generation_aggregate:apply(S1, pause_event()),
    S3 = generation_aggregate:apply(S2, resume_event()),
    Status = element(?F_STATUS, S3),
    ?assertNotEqual(0, Status band ?GENERATION_ACTIVE),
    ?assertEqual(0, Status band ?GENERATION_PAUSED),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S3)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S3)).

%% Apply generation_completed_v1 clears ACTIVE, sets COMPLETED
apply_complete_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    S2 = generation_aggregate:apply(S1, complete_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?GENERATION_COMPLETED),
    ?assertEqual(0, Status band ?GENERATION_ACTIVE),
    ?assertEqual(6000, element(?F_COMPLETED_AT, S2)).

%% Apply generation_archived_v1 sets ARCHIVED
apply_archive_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    S2 = generation_aggregate:apply(S1, archive_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?GENERATION_ARCHIVED),
    ?assertNotEqual(0, Status band ?GENERATION_INITIATED).

%% Full lifecycle: start -> module -> test -> pause -> resume -> complete -> archive
full_lifecycle_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    S2 = generation_aggregate:apply(S1, module_generated_event()),
    S3 = generation_aggregate:apply(S2, test_generated_event()),
    S4 = generation_aggregate:apply(S3, pause_event()),
    S5 = generation_aggregate:apply(S4, resume_event()),
    S6 = generation_aggregate:apply(S5, complete_event()),
    S7 = generation_aggregate:apply(S6, archive_event()),
    Status = element(?F_STATUS, S7),
    %% All lifecycle bits: INITIATED(1) + COMPLETED(8) + ARCHIVED(16) = 25
    %% ACTIVE and PAUSED should be cleared
    ?assertNotEqual(0, Status band ?GENERATION_INITIATED),
    ?assertNotEqual(0, Status band ?GENERATION_COMPLETED),
    ?assertNotEqual(0, Status band ?GENERATION_ARCHIVED),
    ?assertEqual(0, Status band ?GENERATION_ACTIVE),
    ?assertEqual(0, Status band ?GENERATION_PAUSED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S7)),
    %% Modules and tests preserved
    ?assert(maps:is_key(<<"my_module">>, element(?F_GENERATED_MODULES, S7))),
    ?assert(maps:is_key(<<"my_module_tests">>, element(?F_GENERATED_TESTS, S7))).

%% Unknown event leaves state unchanged
unknown_event_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    Unknown = #{<<"event_type">> => <<"some_random_event">>, <<"data">> => <<"whatever">>},
    S2 = generation_aggregate:apply(S1, Unknown),
    ?assertEqual(S1, S2).

%% Events with atom keys work identically to binary keys
atom_keys_test() ->
    S0 = fresh_state(),
    AtomEvent = #{event_type => <<"generation_started_v1">>,
                  division_id => <<"div-atom">>,
                  started_at => 9000,
                  started_by => <<"atom@host">>},
    S1 = generation_aggregate:apply(S0, AtomEvent),
    ?assertEqual(<<"div-atom">>, element(?F_DIVISION_ID, S1)),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?GENERATION_INITIATED).

%% Flag map macro has expected labels
flag_map_test() ->
    Map = ?GENERATION_FLAG_MAP,
    ?assertEqual(<<"Initiated">>, maps:get(?GENERATION_INITIATED, Map)),
    ?assertEqual(<<"Active">>, maps:get(?GENERATION_ACTIVE, Map)),
    ?assertEqual(<<"Paused">>, maps:get(?GENERATION_PAUSED, Map)),
    ?assertEqual(<<"Completed">>, maps:get(?GENERATION_COMPLETED, Map)),
    ?assertEqual(<<"Archived">>, maps:get(?GENERATION_ARCHIVED, Map)).

%% Behaviour callback: apply(State, Event) -- state first (evoq convention)
callback_order_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?GENERATION_INITIATED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)).

%% Multiple modules accumulate in generated_modules map
multiple_modules_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    Mod1 = module_generated_event(),
    Mod2 = Mod1#{<<"module_name">> => <<"second_module">>,
                 <<"module_id">> => <<"mod-002">>},
    S2 = generation_aggregate:apply(S1, Mod1),
    S3 = generation_aggregate:apply(S2, Mod2),
    Modules = element(?F_GENERATED_MODULES, S3),
    ?assertEqual(2, maps:size(Modules)),
    ?assert(maps:is_key(<<"my_module">>, Modules)),
    ?assert(maps:is_key(<<"second_module">>, Modules)).

%% Multiple tests accumulate in generated_tests map
multiple_tests_test() ->
    S0 = fresh_state(),
    S1 = generation_aggregate:apply(S0, start_event()),
    Test1 = test_generated_event(),
    Test2 = Test1#{<<"test_name">> => <<"second_test">>,
                   <<"test_id">> => <<"tst-002">>},
    S2 = generation_aggregate:apply(S1, Test1),
    S3 = generation_aggregate:apply(S2, Test2),
    Tests = element(?F_GENERATED_TESTS, S3),
    ?assertEqual(2, maps:size(Tests)),
    ?assert(maps:is_key(<<"my_module_tests">>, Tests)),
    ?assert(maps:is_key(<<"second_test">>, Tests)).
