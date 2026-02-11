%%% @doc Layer 2: Handler + Aggregate execute/2 tests.
%%% Tests handle/1,2 business logic and execute/2 state machine guards.
%%% No I/O -- builds state via apply/2 chains, then tests commands.
-module(design_division_handler_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("design_division/include/design_status.hrl").

%% Record field positions in design_state
-define(F_DIVISION_ID,          2).
-define(F_STATUS,               3).
-define(F_DESIGNED_AGGREGATES,  4).
-define(F_DESIGNED_EVENTS,      5).

%% ===================================================================
%% Helpers: build state from event sequence
%% ===================================================================

fresh_state() ->
    {ok, S} = design_aggregate:init(<<"div-1">>),
    S.

started_state() ->
    design_aggregate:apply(fresh_state(), start_event_map()).

active_with_aggregate_state() ->
    S = started_state(),
    design_aggregate:apply(S, aggregate_designed_event_map()).

active_with_event_state() ->
    S = started_state(),
    design_aggregate:apply(S, event_designed_event_map()).

paused_state() ->
    design_aggregate:apply(started_state(), pause_event_map()).

completed_state() ->
    design_aggregate:apply(started_state(), complete_event_map()).

archived_state() ->
    design_aggregate:apply(started_state(), archive_event_map()).

%% ===================================================================
%% Event map fixtures (for building state)
%% ===================================================================

start_event_map() ->
    #{<<"event_type">> => <<"design_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

aggregate_designed_event_map() ->
    #{<<"event_type">> => <<"aggregate_designed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"aggregate_id">> => <<"agg-001">>,
      <<"aggregate_name">> => <<"order_aggregate">>,
      <<"stream_pattern">> => <<"order-{id}">>,
      <<"status_flags">> => [],
      <<"description">> => <<"Manages orders">>,
      <<"designed_by">> => <<"architect">>,
      <<"designed_at">> => 2000}.

event_designed_event_map() ->
    #{<<"event_type">> => <<"event_designed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"event_id">> => <<"evt-001">>,
      <<"event_name">> => <<"order_placed_v1">>,
      <<"aggregate_name">> => <<"order_aggregate">>,
      <<"payload_fields">> => [],
      <<"description">> => <<"Order placed">>,
      <<"designed_by">> => <<"architect">>,
      <<"designed_at">> => 3000}.

pause_event_map() ->
    #{<<"event_type">> => <<"design_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"review needed">>}.

complete_event_map() ->
    #{<<"event_type">> => <<"design_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event_map() ->
    #{<<"event_type">> => <<"design_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000,
      <<"archived_by">> => <<"admin">>,
      <<"reason">> => <<"cleanup">>}.

%% ===================================================================
%% Layer 2b: Handler Tests (Business Logic)
%% ===================================================================

%% --- maybe_start_design ---

handle_valid_start_test() ->
    {ok, Cmd} = start_design_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_start_design:handle(Cmd),
    Map = design_started_v1:to_map(Event),
    ?assertEqual(<<"design_started_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

handle_start_invalid_division_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 start_design_v1:new(#{division_id => <<>>})).

%% --- maybe_design_aggregate ---

handle_valid_design_aggregate_test() ->
    {ok, Cmd} = design_aggregate_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"order_aggregate">>,
        stream_pattern => <<"order-{id}">>,
        description => <<"Manages orders">>
    }),
    Context = #{designed_aggregates => #{}},
    {ok, [Event]} = maybe_design_aggregate:handle(Cmd, Context),
    Map = aggregate_designed_v1:to_map(Event),
    ?assertEqual(<<"aggregate_designed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"order_aggregate">>, maps:get(<<"aggregate_name">>, Map)).

handle_duplicate_aggregate_test() ->
    {ok, Cmd} = design_aggregate_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"order_aggregate">>
    }),
    Context = #{designed_aggregates => #{<<"order_aggregate">> => #{}}},
    ?assertEqual({error, aggregate_already_designed},
                 maybe_design_aggregate:handle(Cmd, Context)).

handle_design_aggregate_invalid_name_test() ->
    ?assertEqual({error, {invalid_field, aggregate_name}},
                 design_aggregate_v1:new(#{division_id => <<"div-1">>,
                                           aggregate_name => <<>>})).

%% --- maybe_design_event ---

handle_valid_design_event_test() ->
    {ok, Cmd} = design_event_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>,
        aggregate_name => <<"order_aggregate">>,
        description => <<"Order was placed">>
    }),
    Context = #{designed_events => #{}},
    {ok, [Event]} = maybe_design_event:handle(Cmd, Context),
    Map = event_designed_v1:to_map(Event),
    ?assertEqual(<<"event_designed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"order_placed_v1">>, maps:get(<<"event_name">>, Map)).

handle_duplicate_event_test() ->
    {ok, Cmd} = design_event_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>,
        aggregate_name => <<"order_aggregate">>
    }),
    Context = #{designed_events => #{<<"order_placed_v1">> => #{}}},
    ?assertEqual({error, event_already_designed},
                 maybe_design_event:handle(Cmd, Context)).

handle_design_event_invalid_name_test() ->
    ?assertEqual({error, {invalid_field, event_name}},
                 design_event_v1:new(#{division_id => <<"div-1">>,
                                       event_name => <<>>,
                                       aggregate_name => <<"agg">>})).

%% --- maybe_pause_design ---

handle_valid_pause_test() ->
    {ok, Cmd} = pause_design_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"waiting for review">>
    }),
    {ok, [Event]} = maybe_pause_design:handle(Cmd),
    Map = design_paused_v1:to_map(Event),
    ?assertEqual(<<"design_paused_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"waiting for review">>, maps:get(<<"reason">>, Map)).

%% --- maybe_resume_design ---

handle_valid_resume_test() ->
    {ok, Cmd} = resume_design_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_resume_design:handle(Cmd),
    Map = design_resumed_v1:to_map(Event),
    ?assertEqual(<<"design_resumed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

%% --- maybe_complete_design ---

handle_valid_complete_test() ->
    {ok, Cmd} = complete_design_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_complete_design:handle(Cmd),
    Map = design_completed_v1:to_map(Event),
    ?assertEqual(<<"design_completed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

%% --- maybe_archive_design ---

handle_valid_archive_test() ->
    {ok, Cmd} = archive_design_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    {ok, [Event]} = maybe_archive_design:handle(Cmd),
    Map = design_archived_v1:to_map(Event),
    ?assertEqual(<<"design_archived_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)).

%% ===================================================================
%% Layer 2c: Aggregate execute/2 State Machine Tests
%% ===================================================================

%% --- start_design command ---

execute_start_on_fresh_test() ->
    Cmd = #{<<"command_type">> => <<"start_design">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = design_aggregate:execute(fresh_state(), Cmd),
    ?assertEqual(<<"design_started_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_start_already_started_test() ->
    Cmd = #{<<"command_type">> => <<"start_design">>,
            <<"division_id">> => <<"div-1">>},
    %% After start, status has INITIATED set, so start_design is not recognized
    %% by the status=0 clause; falls through to lifecycle which doesn't handle it
    Result = design_aggregate:execute(started_state(), Cmd),
    ?assertMatch({error, _}, Result).

%% --- design_aggregate command ---

execute_design_aggregate_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"design_aggregate">>,
            <<"division_id">> => <<"div-1">>,
            <<"aggregate_name">> => <<"payment_aggregate">>},
    {ok, [EventMap]} = design_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"aggregate_designed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_design_aggregate_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"design_aggregate">>,
            <<"division_id">> => <<"div-1">>,
            <<"aggregate_name">> => <<"payment_aggregate">>},
    S = paused_state(),
    Status = element(?F_STATUS, S),
    ?assertMatch({error, {not_active, Status}},
                 design_aggregate:execute(S, Cmd)).

execute_design_aggregate_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"design_aggregate">>,
            <<"division_id">> => <<"div-1">>,
            <<"aggregate_name">> => <<"payment_aggregate">>},
    ?assertEqual({error, design_not_started},
                 design_aggregate:execute(fresh_state(), Cmd)).

execute_design_aggregate_duplicate_test() ->
    Cmd = #{<<"command_type">> => <<"design_aggregate">>,
            <<"division_id">> => <<"div-1">>,
            <<"aggregate_name">> => <<"order_aggregate">>},
    ?assertEqual({error, aggregate_already_designed},
                 design_aggregate:execute(active_with_aggregate_state(), Cmd)).

%% --- design_event command ---

execute_design_event_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"design_event">>,
            <<"division_id">> => <<"div-1">>,
            <<"event_name">> => <<"order_placed_v1">>,
            <<"aggregate_name">> => <<"order_aggregate">>},
    {ok, [EventMap]} = design_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"event_designed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_design_event_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"design_event">>,
            <<"division_id">> => <<"div-1">>,
            <<"event_name">> => <<"order_placed_v1">>,
            <<"aggregate_name">> => <<"order_aggregate">>},
    S = paused_state(),
    Status = element(?F_STATUS, S),
    ?assertMatch({error, {not_active, Status}},
                 design_aggregate:execute(S, Cmd)).

execute_design_event_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"design_event">>,
            <<"division_id">> => <<"div-1">>,
            <<"event_name">> => <<"order_placed_v1">>,
            <<"aggregate_name">> => <<"order_aggregate">>},
    ?assertEqual({error, design_not_started},
                 design_aggregate:execute(fresh_state(), Cmd)).

execute_design_event_duplicate_test() ->
    Cmd = #{<<"command_type">> => <<"design_event">>,
            <<"division_id">> => <<"div-1">>,
            <<"event_name">> => <<"order_placed_v1">>,
            <<"aggregate_name">> => <<"order_aggregate">>},
    ?assertEqual({error, event_already_designed},
                 design_aggregate:execute(active_with_event_state(), Cmd)).

%% --- pause_design command ---

execute_pause_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"pause_design">>,
            <<"division_id">> => <<"div-1">>,
            <<"reason">> => <<"need review">>},
    {ok, [EventMap]} = design_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"design_paused_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_pause_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"pause_design">>,
            <<"division_id">> => <<"div-1">>},
    S = paused_state(),
    Status = element(?F_STATUS, S),
    ?assertMatch({error, {not_active, Status}},
                 design_aggregate:execute(S, Cmd)).

execute_pause_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"pause_design">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, design_not_started},
                 design_aggregate:execute(fresh_state(), Cmd)).

%% --- resume_design command ---

execute_resume_on_paused_test() ->
    Cmd = #{<<"command_type">> => <<"resume_design">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = design_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"design_resumed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_resume_not_paused_test() ->
    Cmd = #{<<"command_type">> => <<"resume_design">>,
            <<"division_id">> => <<"div-1">>},
    S = started_state(),
    Status = element(?F_STATUS, S),
    ?assertMatch({error, {not_paused, Status}},
                 design_aggregate:execute(S, Cmd)).

execute_resume_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"resume_design">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, design_not_started},
                 design_aggregate:execute(fresh_state(), Cmd)).

%% --- complete_design command ---

execute_complete_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"complete_design">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = design_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"design_completed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_complete_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"complete_design">>,
            <<"division_id">> => <<"div-1">>},
    S = paused_state(),
    Status = element(?F_STATUS, S),
    ?assertMatch({error, {not_active, Status}},
                 design_aggregate:execute(S, Cmd)).

execute_complete_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"complete_design">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, design_not_started},
                 design_aggregate:execute(fresh_state(), Cmd)).

%% --- archive_design command ---

execute_archive_on_started_test() ->
    Cmd = #{<<"command_type">> => <<"archive_design">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = design_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"design_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_on_paused_test() ->
    Cmd = #{<<"command_type">> => <<"archive_design">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = design_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"design_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_on_completed_test() ->
    Cmd = #{<<"command_type">> => <<"archive_design">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = design_aggregate:execute(completed_state(), Cmd),
    ?assertEqual(<<"design_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_already_archived_test() ->
    Cmd = #{<<"command_type">> => <<"archive_design">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, design_archived},
                 design_aggregate:execute(archived_state(), Cmd)).

execute_archive_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"archive_design">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, design_not_started},
                 design_aggregate:execute(fresh_state(), Cmd)).

%% --- unknown command ---

execute_unknown_command_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, design_not_started},
                 design_aggregate:execute(fresh_state(), Cmd)).

execute_unknown_on_started_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, unknown_command},
                 design_aggregate:execute(started_state(), Cmd)).

execute_missing_command_type_test() ->
    ?assertEqual({error, design_not_started},
                 design_aggregate:execute(fresh_state(), #{<<"data">> => <<"stuff">>})).

%% --- evoq callback order: execute(State, Payload) ---

execute_evoq_callback_order_test() ->
    State = fresh_state(),
    Payload = #{<<"command_type">> => <<"start_design">>,
                <<"division_id">> => <<"div-order">>},
    %% Correct order: State first, Payload second
    {ok, _Events} = design_aggregate:execute(State, Payload).

%% --- Lifecycle transitions ---

execute_start_pause_resume_complete_test() ->
    S0 = fresh_state(),
    %% Start
    StartCmd = #{<<"command_type">> => <<"start_design">>,
                 <<"division_id">> => <<"div-1">>},
    {ok, [StartEvt]} = design_aggregate:execute(S0, StartCmd),
    S1 = design_aggregate:apply(S0, StartEvt),
    %% Pause
    PauseCmd = #{<<"command_type">> => <<"pause_design">>,
                 <<"division_id">> => <<"div-1">>,
                 <<"reason">> => <<"review">>},
    {ok, [PauseEvt]} = design_aggregate:execute(S1, PauseCmd),
    S2 = design_aggregate:apply(S1, PauseEvt),
    %% Resume
    ResumeCmd = #{<<"command_type">> => <<"resume_design">>,
                  <<"division_id">> => <<"div-1">>},
    {ok, [ResumeEvt]} = design_aggregate:execute(S2, ResumeCmd),
    S3 = design_aggregate:apply(S2, ResumeEvt),
    %% Complete
    CompleteCmd = #{<<"command_type">> => <<"complete_design">>,
                    <<"division_id">> => <<"div-1">>},
    {ok, [CompleteEvt]} = design_aggregate:execute(S3, CompleteCmd),
    ?assertEqual(<<"design_completed_v1">>, maps:get(<<"event_type">>, CompleteEvt)).

%% Design aggregate with context built from state
execute_design_aggregate_uses_state_context_test() ->
    %% Start and design first aggregate
    S0 = fresh_state(),
    StartCmd = #{<<"command_type">> => <<"start_design">>,
                 <<"division_id">> => <<"div-1">>},
    {ok, [StartEvt]} = design_aggregate:execute(S0, StartCmd),
    S1 = design_aggregate:apply(S0, StartEvt),
    %% Design first aggregate
    AggCmd1 = #{<<"command_type">> => <<"design_aggregate">>,
                <<"division_id">> => <<"div-1">>,
                <<"aggregate_name">> => <<"order_aggregate">>},
    {ok, [AggEvt1]} = design_aggregate:execute(S1, AggCmd1),
    S2 = design_aggregate:apply(S1, AggEvt1),
    %% Duplicate should fail (context from state)
    ?assertEqual({error, aggregate_already_designed},
                 design_aggregate:execute(S2, AggCmd1)),
    %% Different aggregate should succeed
    AggCmd2 = AggCmd1#{<<"aggregate_name">> => <<"payment_aggregate">>},
    {ok, [_]} = design_aggregate:execute(S2, AggCmd2).

%% Design event with context built from state
execute_design_event_uses_state_context_test() ->
    S0 = fresh_state(),
    StartCmd = #{<<"command_type">> => <<"start_design">>,
                 <<"division_id">> => <<"div-1">>},
    {ok, [StartEvt]} = design_aggregate:execute(S0, StartCmd),
    S1 = design_aggregate:apply(S0, StartEvt),
    %% Design first event
    EvtCmd1 = #{<<"command_type">> => <<"design_event">>,
                <<"division_id">> => <<"div-1">>,
                <<"event_name">> => <<"order_placed_v1">>,
                <<"aggregate_name">> => <<"order_aggregate">>},
    {ok, [EvtEvt1]} = design_aggregate:execute(S1, EvtCmd1),
    S2 = design_aggregate:apply(S1, EvtEvt1),
    %% Duplicate should fail
    ?assertEqual({error, event_already_designed},
                 design_aggregate:execute(S2, EvtCmd1)),
    %% Different event should succeed
    EvtCmd2 = EvtCmd1#{<<"event_name">> => <<"order_shipped_v1">>},
    {ok, [_]} = design_aggregate:execute(S2, EvtCmd2).
