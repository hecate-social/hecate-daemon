%%% @doc Tests for venture_aggregate (execute/2 + apply_event/2).
%%%
%%% Pure logic tests — no external deps (no ReckonDB, no mesh).
%%% Tests all 9 command types through the aggregate, state guards,
%%% and bit flag transitions.
-module(venture_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_venture_lifecycle/include/venture_lifecycle_status.hrl").
-include_lib("guide_venture_lifecycle/include/venture_state.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

aggregate_test_() ->
    [
        %% Execute: initiate venture
        {"initiate on fresh state succeeds",        fun exec_initiate_ok/0},
        {"initiate requires name",                  fun exec_initiate_missing_name/0},
        {"only initiate allowed on fresh state",    fun exec_non_initiate_on_fresh/0},

        %% Execute: state guards
        {"archived venture rejects all commands",   fun exec_archived_rejects_all/0},
        {"unknown command returns error",           fun exec_unknown_command/0},

        %% Execute: vision refinement
        {"refine vision succeeds after initiate",   fun exec_refine_vision_ok/0},
        {"refine vision blocked after submit",      fun exec_refine_after_submit/0},

        %% Execute: vision submission
        {"submit vision succeeds",                  fun exec_submit_vision_ok/0},
        {"submit vision blocked if already submitted", fun exec_submit_twice/0},

        %% Execute: discovery lifecycle
        {"start discovery succeeds",                fun exec_start_discovery_ok/0},
        {"start discovery blocked if already active", fun exec_start_discovery_twice/0},
        {"start discovery blocked if completed",    fun exec_start_discovery_after_complete/0},
        {"identify division succeeds during discovery", fun exec_identify_division_ok/0},
        {"identify division blocked when not discovering", fun exec_identify_division_not_active/0},
        {"identify duplicate division blocked",     fun exec_identify_division_duplicate/0},
        {"pause discovery succeeds",                fun exec_pause_discovery_ok/0},
        {"pause discovery blocked when not active", fun exec_pause_not_active/0},
        {"resume discovery succeeds after pause",   fun exec_resume_discovery_ok/0},
        {"resume blocked when not paused",          fun exec_resume_not_paused/0},
        {"complete discovery succeeds",             fun exec_complete_discovery_ok/0},
        {"complete blocked when not active",        fun exec_complete_not_active/0},

        %% Execute: archive
        {"archive venture succeeds",               fun exec_archive_ok/0},

        %% Apply: state transitions
        {"apply venture_initiated sets state",      fun apply_initiated/0},
        {"apply vision_refined updates fields",     fun apply_vision_refined/0},
        {"apply vision_refined partial update",     fun apply_vision_refined_partial/0},
        {"apply vision_submitted sets flag",        fun apply_vision_submitted/0},
        {"apply discovery_started sets flag",       fun apply_discovery_started/0},
        {"apply division_identified adds to map",   fun apply_division_identified/0},
        {"apply discovery_paused toggles flags",    fun apply_discovery_paused/0},
        {"apply discovery_resumed toggles flags",   fun apply_discovery_resumed/0},
        {"apply discovery_completed toggles flags", fun apply_discovery_completed/0},
        {"apply venture_archived sets flag",        fun apply_archived/0},
        {"apply unknown event leaves state unchanged", fun apply_unknown_event/0},

        %% Apply: binary vs atom keys
        {"apply handles binary keys",              fun apply_binary_keys/0},
        {"apply handles atom keys",                fun apply_atom_keys/0},

        %% Full lifecycle integration
        {"full venture lifecycle flow",             fun full_lifecycle/0}
    ].

%% ===================================================================
%% Helpers
%% ===================================================================

fresh() -> venture_aggregate:initial_state().

%% Build a state by applying a sequence of events
apply_events(Events) ->
    lists:foldl(fun(E, S) -> venture_aggregate:apply_event(E, S) end, fresh(), Events).

initiated_state() ->
    apply_events([initiated_event()]).

initiated_event() ->
    #{<<"event_type">> => <<"venture_initiated_v1">>,
      <<"venture_id">> => <<"v-test-1">>,
      <<"name">> => <<"Test Venture">>,
      <<"brief">> => <<"A test venture">>,
      <<"repos">> => [<<"repo1">>],
      <<"skills">> => [<<"erlang">>],
      <<"context_map">> => #{<<"domain">> => <<"test">>},
      <<"initiated_by">> => <<"user@test">>,
      <<"initiated_at">> => 1000}.

submitted_state() ->
    apply_events([
        initiated_event(),
        #{<<"event_type">> => <<"vision_submitted_v1">>,
          <<"venture_id">> => <<"v-test-1">>}
    ]).

discovering_state() ->
    apply_events([
        initiated_event(),
        #{<<"event_type">> => <<"vision_submitted_v1">>,
          <<"venture_id">> => <<"v-test-1">>},
        #{<<"event_type">> => <<"discovery_started_v1">>,
          <<"venture_id">> => <<"v-test-1">>,
          <<"started_at">> => 2000}
    ]).

paused_state() ->
    apply_events([
        initiated_event(),
        #{<<"event_type">> => <<"vision_submitted_v1">>,
          <<"venture_id">> => <<"v-test-1">>},
        #{<<"event_type">> => <<"discovery_started_v1">>,
          <<"venture_id">> => <<"v-test-1">>,
          <<"started_at">> => 2000},
        #{<<"event_type">> => <<"discovery_paused_v1">>,
          <<"venture_id">> => <<"v-test-1">>,
          <<"paused_at">> => 3000,
          <<"reason">> => <<"blocked">>}
    ]).

completed_state() ->
    apply_events([
        initiated_event(),
        #{<<"event_type">> => <<"vision_submitted_v1">>,
          <<"venture_id">> => <<"v-test-1">>},
        #{<<"event_type">> => <<"discovery_started_v1">>,
          <<"venture_id">> => <<"v-test-1">>,
          <<"started_at">> => 2000},
        #{<<"event_type">> => <<"discovery_completed_v1">>,
          <<"venture_id">> => <<"v-test-1">>,
          <<"completed_at">> => 4000}
    ]).

archived_state() ->
    apply_events([
        initiated_event(),
        #{<<"event_type">> => <<"venture_archived_v1">>,
          <<"venture_id">> => <<"v-test-1">>}
    ]).

initiate_cmd() ->
    #{<<"command_type">> => <<"initiate_venture">>,
      <<"venture_id">> => <<"v-test-new">>,
      <<"name">> => <<"New Venture">>}.

%% ===================================================================
%% Execute: Initiate Venture
%% ===================================================================

exec_initiate_ok() ->
    {ok, [Event]} = venture_aggregate:execute(fresh(), initiate_cmd()),
    ?assertEqual(<<"venture_initiated_v1">>, maps:get(<<"event_type">>, Event)),
    ?assertEqual(<<"New Venture">>, maps:get(<<"name">>, Event)).

exec_initiate_missing_name() ->
    %% NOTE: The aggregate crashes with badmatch because execute_initiate_venture/1
    %% does {ok, Cmd} = from_map(Payload) without handling the error case.
    %% This is a known deficiency — from_map errors should be caught gracefully.
    Cmd = #{<<"command_type">> => <<"initiate_venture">>},
    ?assertError({badmatch, {error, missing_required_fields}},
                 venture_aggregate:execute(fresh(), Cmd)).

exec_non_initiate_on_fresh() ->
    Cmd = #{<<"command_type">> => <<"refine_vision">>,
            <<"venture_id">> => <<"v-test-1">>},
    ?assertEqual({error, venture_not_initiated},
                 venture_aggregate:execute(fresh(), Cmd)).

%% ===================================================================
%% Execute: State Guards
%% ===================================================================

exec_archived_rejects_all() ->
    State = archived_state(),
    Cmd = #{<<"command_type">> => <<"refine_vision">>,
            <<"venture_id">> => <<"v-test-1">>},
    ?assertEqual({error, venture_archived},
                 venture_aggregate:execute(State, Cmd)).

exec_unknown_command() ->
    Cmd = #{<<"command_type">> => <<"do_something_weird">>},
    ?assertEqual({error, unknown_command},
                 venture_aggregate:execute(initiated_state(), Cmd)).

%% ===================================================================
%% Execute: Vision
%% ===================================================================

exec_refine_vision_ok() ->
    Cmd = #{<<"command_type">> => <<"refine_vision">>,
            <<"venture_id">> => <<"v-test-1">>,
            <<"brief">> => <<"Updated brief">>},
    {ok, [Event]} = venture_aggregate:execute(initiated_state(), Cmd),
    ?assertEqual(<<"vision_refined_v1">>, maps:get(<<"event_type">>, Event)).

exec_refine_after_submit() ->
    Cmd = #{<<"command_type">> => <<"refine_vision">>,
            <<"venture_id">> => <<"v-test-1">>},
    ?assertEqual({error, vision_already_submitted},
                 venture_aggregate:execute(submitted_state(), Cmd)).

exec_submit_vision_ok() ->
    Cmd = #{<<"command_type">> => <<"submit_vision">>,
            <<"venture_id">> => <<"v-test-1">>},
    {ok, [Event]} = venture_aggregate:execute(initiated_state(), Cmd),
    ?assertEqual(<<"vision_submitted_v1">>, maps:get(<<"event_type">>, Event)).

exec_submit_twice() ->
    Cmd = #{<<"command_type">> => <<"submit_vision">>,
            <<"venture_id">> => <<"v-test-1">>},
    ?assertEqual({error, vision_already_submitted},
                 venture_aggregate:execute(submitted_state(), Cmd)).

%% ===================================================================
%% Execute: Discovery Lifecycle
%% ===================================================================

exec_start_discovery_ok() ->
    Cmd = #{<<"command_type">> => <<"start_discovery">>,
            <<"venture_id">> => <<"v-test-1">>},
    {ok, [Event]} = venture_aggregate:execute(initiated_state(), Cmd),
    ?assertEqual(<<"discovery_started_v1">>, maps:get(<<"event_type">>, Event)).

exec_start_discovery_twice() ->
    Cmd = #{<<"command_type">> => <<"start_discovery">>,
            <<"venture_id">> => <<"v-test-1">>},
    ?assertEqual({error, discovery_already_started},
                 venture_aggregate:execute(discovering_state(), Cmd)).

exec_start_discovery_after_complete() ->
    Cmd = #{<<"command_type">> => <<"start_discovery">>,
            <<"venture_id">> => <<"v-test-1">>},
    ?assertEqual({error, discovery_already_completed},
                 venture_aggregate:execute(completed_state(), Cmd)).

exec_identify_division_ok() ->
    Cmd = #{<<"command_type">> => <<"identify_division">>,
            <<"venture_id">> => <<"v-test-1">>,
            <<"context_name">> => <<"auth_division">>},
    {ok, [Event]} = venture_aggregate:execute(discovering_state(), Cmd),
    ?assertEqual(<<"division_identified_v1">>, maps:get(<<"event_type">>, Event)),
    ?assertEqual(<<"auth_division">>, maps:get(<<"context_name">>, Event)).

exec_identify_division_not_active() ->
    Cmd = #{<<"command_type">> => <<"identify_division">>,
            <<"venture_id">> => <<"v-test-1">>,
            <<"context_name">> => <<"auth">>},
    ?assertEqual({error, discovery_not_active},
                 venture_aggregate:execute(initiated_state(), Cmd)).

exec_identify_division_duplicate() ->
    State0 = discovering_state(),
    %% First: identify auth_division
    EvtMap = #{<<"event_type">> => <<"division_identified_v1">>,
               <<"venture_id">> => <<"v-test-1">>,
               <<"division_id">> => <<"div-1">>,
               <<"context_name">> => <<"auth_division">>},
    State1 = venture_aggregate:apply_event(EvtMap, State0),
    %% Second: try to identify same context_name
    Cmd = #{<<"command_type">> => <<"identify_division">>,
            <<"venture_id">> => <<"v-test-1">>,
            <<"context_name">> => <<"auth_division">>},
    ?assertEqual({error, division_already_identified},
                 venture_aggregate:execute(State1, Cmd)).

exec_pause_discovery_ok() ->
    Cmd = #{<<"command_type">> => <<"pause_discovery">>,
            <<"venture_id">> => <<"v-test-1">>,
            <<"reason">> => <<"need more info">>},
    {ok, [Event]} = venture_aggregate:execute(discovering_state(), Cmd),
    ?assertEqual(<<"discovery_paused_v1">>, maps:get(<<"event_type">>, Event)).

exec_pause_not_active() ->
    Cmd = #{<<"command_type">> => <<"pause_discovery">>,
            <<"venture_id">> => <<"v-test-1">>,
            <<"reason">> => <<"why?">>},
    ?assertEqual({error, discovery_not_active},
                 venture_aggregate:execute(initiated_state(), Cmd)).

exec_resume_discovery_ok() ->
    Cmd = #{<<"command_type">> => <<"resume_discovery">>,
            <<"venture_id">> => <<"v-test-1">>},
    {ok, [Event]} = venture_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"discovery_resumed_v1">>, maps:get(<<"event_type">>, Event)).

exec_resume_not_paused() ->
    Cmd = #{<<"command_type">> => <<"resume_discovery">>,
            <<"venture_id">> => <<"v-test-1">>},
    ?assertEqual({error, discovery_not_paused},
                 venture_aggregate:execute(discovering_state(), Cmd)).

exec_complete_discovery_ok() ->
    Cmd = #{<<"command_type">> => <<"complete_discovery">>,
            <<"venture_id">> => <<"v-test-1">>},
    {ok, [Event]} = venture_aggregate:execute(discovering_state(), Cmd),
    ?assertEqual(<<"discovery_completed_v1">>, maps:get(<<"event_type">>, Event)).

exec_complete_not_active() ->
    Cmd = #{<<"command_type">> => <<"complete_discovery">>,
            <<"venture_id">> => <<"v-test-1">>},
    ?assertEqual({error, discovery_not_active},
                 venture_aggregate:execute(initiated_state(), Cmd)).

%% ===================================================================
%% Execute: Archive
%% ===================================================================

exec_archive_ok() ->
    Cmd = #{<<"command_type">> => <<"archive_venture">>,
            <<"venture_id">> => <<"v-test-1">>,
            <<"reason">> => <<"no longer needed">>},
    {ok, [Event]} = venture_aggregate:execute(initiated_state(), Cmd),
    ?assertEqual(<<"venture_archived_v1">>, maps:get(<<"event_type">>, Event)).

%% ===================================================================
%% Apply: State Transitions
%% ===================================================================

apply_initiated() ->
    State = initiated_state(),
    ?assertEqual(<<"v-test-1">>, State#venture_state.venture_id),
    ?assertEqual(<<"Test Venture">>, State#venture_state.name),
    ?assertEqual(<<"A test venture">>, State#venture_state.brief),
    ?assertEqual([<<"repo1">>], State#venture_state.repos),
    ?assertEqual([<<"erlang">>], State#venture_state.skills),
    ?assertEqual(1000, State#venture_state.initiated_at),
    ?assertEqual(<<"user@test">>, State#venture_state.initiated_by),
    ?assert(State#venture_state.status band ?VL_INITIATED =/= 0).

apply_vision_refined() ->
    Event = #{<<"event_type">> => <<"vision_refined_v1">>,
              <<"venture_id">> => <<"v-test-1">>,
              <<"brief">> => <<"New brief">>,
              <<"repos">> => [<<"repo2">>],
              <<"skills">> => [<<"go">>],
              <<"context_map">> => #{<<"x">> => <<"y">>}},
    State = venture_aggregate:apply_event(Event, initiated_state()),
    ?assertEqual(<<"New brief">>, State#venture_state.brief),
    ?assertEqual([<<"repo2">>], State#venture_state.repos),
    ?assertEqual([<<"go">>], State#venture_state.skills),
    ?assertEqual(#{<<"x">> => <<"y">>}, State#venture_state.context_map),
    ?assert(State#venture_state.status band ?VL_VISION_REFINED =/= 0).

apply_vision_refined_partial() ->
    %% Only update brief, leave repos/skills/context_map unchanged
    Event = #{<<"event_type">> => <<"vision_refined_v1">>,
              <<"venture_id">> => <<"v-test-1">>,
              <<"brief">> => <<"Only brief updated">>},
    State = venture_aggregate:apply_event(Event, initiated_state()),
    ?assertEqual(<<"Only brief updated">>, State#venture_state.brief),
    %% Original values preserved
    ?assertEqual([<<"repo1">>], State#venture_state.repos),
    ?assertEqual([<<"erlang">>], State#venture_state.skills).

apply_vision_submitted() ->
    Event = #{<<"event_type">> => <<"vision_submitted_v1">>,
              <<"venture_id">> => <<"v-test-1">>},
    State = venture_aggregate:apply_event(Event, initiated_state()),
    ?assert(State#venture_state.status band ?VL_SUBMITTED =/= 0).

apply_discovery_started() ->
    Event = #{<<"event_type">> => <<"discovery_started_v1">>,
              <<"venture_id">> => <<"v-test-1">>,
              <<"started_at">> => 5000},
    State = venture_aggregate:apply_event(Event, initiated_state()),
    ?assert(State#venture_state.status band ?VL_DISCOVERING =/= 0),
    ?assertEqual(5000, State#venture_state.discovery_started_at).

apply_division_identified() ->
    Event = #{<<"event_type">> => <<"division_identified_v1">>,
              <<"venture_id">> => <<"v-test-1">>,
              <<"division_id">> => <<"div-abc">>,
              <<"context_name">> => <<"payments">>},
    State = venture_aggregate:apply_event(Event, discovering_state()),
    Discovered = State#venture_state.discovered_divisions,
    ?assertEqual(<<"div-abc">>, maps:get(<<"payments">>, Discovered)).

apply_discovery_paused() ->
    Event = #{<<"event_type">> => <<"discovery_paused_v1">>,
              <<"venture_id">> => <<"v-test-1">>,
              <<"paused_at">> => 6000,
              <<"reason">> => <<"waiting for feedback">>},
    State = venture_aggregate:apply_event(Event, discovering_state()),
    ?assert(State#venture_state.status band ?VL_DISCOVERY_PAUSED =/= 0),
    ?assert(State#venture_state.status band ?VL_DISCOVERING =:= 0),
    ?assertEqual(6000, State#venture_state.discovery_paused_at),
    ?assertEqual(<<"waiting for feedback">>, State#venture_state.discovery_pause_reason).

apply_discovery_resumed() ->
    Event = #{<<"event_type">> => <<"discovery_resumed_v1">>,
              <<"venture_id">> => <<"v-test-1">>},
    State = venture_aggregate:apply_event(Event, paused_state()),
    ?assert(State#venture_state.status band ?VL_DISCOVERING =/= 0),
    ?assert(State#venture_state.status band ?VL_DISCOVERY_PAUSED =:= 0),
    ?assertEqual(undefined, State#venture_state.discovery_paused_at),
    ?assertEqual(undefined, State#venture_state.discovery_pause_reason).

apply_discovery_completed() ->
    Event = #{<<"event_type">> => <<"discovery_completed_v1">>,
              <<"venture_id">> => <<"v-test-1">>,
              <<"completed_at">> => 9000},
    State = venture_aggregate:apply_event(Event, discovering_state()),
    ?assert(State#venture_state.status band ?VL_DISCOVERY_COMPLETED =/= 0),
    ?assert(State#venture_state.status band ?VL_DISCOVERING =:= 0),
    ?assertEqual(9000, State#venture_state.discovery_completed_at).

apply_archived() ->
    Event = #{<<"event_type">> => <<"venture_archived_v1">>,
              <<"venture_id">> => <<"v-test-1">>},
    State = venture_aggregate:apply_event(Event, initiated_state()),
    ?assert(State#venture_state.status band ?VL_ARCHIVED =/= 0).

apply_unknown_event() ->
    Event = #{<<"event_type">> => <<"something_weird_v1">>},
    State = initiated_state(),
    ?assertEqual(State, venture_aggregate:apply_event(Event, State)).

%% ===================================================================
%% Apply: binary vs atom keys
%% ===================================================================

apply_binary_keys() ->
    Event = #{<<"event_type">> => <<"venture_initiated_v1">>,
              <<"venture_id">> => <<"v-bin">>,
              <<"name">> => <<"Binary Keys">>,
              <<"initiated_at">> => 1000},
    State = venture_aggregate:apply_event(Event, fresh()),
    ?assertEqual(<<"v-bin">>, State#venture_state.venture_id),
    ?assertEqual(<<"Binary Keys">>, State#venture_state.name).

apply_atom_keys() ->
    Event = #{event_type => <<"venture_initiated_v1">>,
              venture_id => <<"v-atom">>,
              name => <<"Atom Keys">>,
              initiated_at => 2000},
    State = venture_aggregate:apply_event(Event, fresh()),
    ?assertEqual(<<"v-atom">>, State#venture_state.venture_id),
    ?assertEqual(<<"Atom Keys">>, State#venture_state.name).

%% ===================================================================
%% Full lifecycle integration
%% ===================================================================

full_lifecycle() ->
    S0 = fresh(),

    %% 1. Initiate
    {ok, [E1]} = venture_aggregate:execute(S0,
        #{<<"command_type">> => <<"initiate_venture">>,
          <<"venture_id">> => <<"v-full">>,
          <<"name">> => <<"Full Lifecycle">>}),
    S1 = venture_aggregate:apply_event(E1, S0),
    ?assert(S1#venture_state.status band ?VL_INITIATED =/= 0),

    %% 2. Refine vision
    {ok, [E2]} = venture_aggregate:execute(S1,
        #{<<"command_type">> => <<"refine_vision">>,
          <<"venture_id">> => <<"v-full">>,
          <<"brief">> => <<"Refined">>}),
    S2 = venture_aggregate:apply_event(E2, S1),
    ?assert(S2#venture_state.status band ?VL_VISION_REFINED =/= 0),

    %% 3. Submit vision
    {ok, [E3]} = venture_aggregate:execute(S2,
        #{<<"command_type">> => <<"submit_vision">>,
          <<"venture_id">> => <<"v-full">>}),
    S3 = venture_aggregate:apply_event(E3, S2),
    ?assert(S3#venture_state.status band ?VL_SUBMITTED =/= 0),

    %% 4. Start discovery
    {ok, [E4]} = venture_aggregate:execute(S3,
        #{<<"command_type">> => <<"start_discovery">>,
          <<"venture_id">> => <<"v-full">>}),
    S4 = venture_aggregate:apply_event(E4, S3),
    ?assert(S4#venture_state.status band ?VL_DISCOVERING =/= 0),

    %% 5. Identify a division
    {ok, [E5]} = venture_aggregate:execute(S4,
        #{<<"command_type">> => <<"identify_division">>,
          <<"venture_id">> => <<"v-full">>,
          <<"context_name">> => <<"payments">>}),
    S5 = venture_aggregate:apply_event(E5, S4),
    ?assert(maps:is_key(<<"payments">>, S5#venture_state.discovered_divisions)),

    %% 6. Pause discovery
    {ok, [E6]} = venture_aggregate:execute(S5,
        #{<<"command_type">> => <<"pause_discovery">>,
          <<"venture_id">> => <<"v-full">>,
          <<"reason">> => <<"thinking">>}),
    S6 = venture_aggregate:apply_event(E6, S5),
    ?assert(S6#venture_state.status band ?VL_DISCOVERY_PAUSED =/= 0),

    %% 7. Resume discovery
    {ok, [E7]} = venture_aggregate:execute(S6,
        #{<<"command_type">> => <<"resume_discovery">>,
          <<"venture_id">> => <<"v-full">>}),
    S7 = venture_aggregate:apply_event(E7, S6),
    ?assert(S7#venture_state.status band ?VL_DISCOVERING =/= 0),

    %% 8. Complete discovery
    {ok, [E8]} = venture_aggregate:execute(S7,
        #{<<"command_type">> => <<"complete_discovery">>,
          <<"venture_id">> => <<"v-full">>}),
    S8 = venture_aggregate:apply_event(E8, S7),
    ?assert(S8#venture_state.status band ?VL_DISCOVERY_COMPLETED =/= 0),

    %% 9. Archive
    {ok, [E9]} = venture_aggregate:execute(S8,
        #{<<"command_type">> => <<"archive_venture">>,
          <<"venture_id">> => <<"v-full">>,
          <<"reason">> => <<"done">>}),
    S9 = venture_aggregate:apply_event(E9, S8),
    ?assert(S9#venture_state.status band ?VL_ARCHIVED =/= 0),

    %% Verify archived rejects
    ?assertEqual({error, venture_archived},
                 venture_aggregate:execute(S9,
                     #{<<"command_type">> => <<"refine_vision">>,
                       <<"venture_id">> => <<"v-full">>})).

