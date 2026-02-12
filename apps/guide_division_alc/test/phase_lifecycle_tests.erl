%%% @doc Tests for phase lifecycle desks (start, pause, resume, complete).
%%% Validates handler business logic across all four phase operations.
-module(phase_lifecycle_tests).

-include_lib("eunit/include/eunit.hrl").

phase_lifecycle_test_() ->
    [
        {"start_phase: valid command produces event",       fun start_valid/0},
        {"start_phase: invalid phase is rejected",          fun start_invalid_phase/0},
        {"start_phase: empty division_id is rejected",      fun start_empty_division_id/0},
        {"pause_phase: valid command produces event",       fun pause_valid/0},
        {"pause_phase: empty division_id is rejected",      fun pause_empty_id/0},
        {"resume_phase: valid command produces event",      fun resume_valid/0},
        {"resume_phase: empty division_id is rejected",     fun resume_empty_id/0},
        {"complete_phase: valid command produces event",    fun complete_valid/0},
        {"complete_phase: empty division_id is rejected",   fun complete_empty_id/0}
    ].

%% --- start_phase ---

start_valid() ->
    {ok, Cmd} = start_phase_v1:new(#{
        division_id => <<"div-1">>,
        phase => <<"dna">>
    }),
    {ok, [Event]} = maybe_start_phase:handle(Cmd),
    Map = phase_started_v1:to_map(Event),
    ?assertEqual(<<"phase_started_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>,            maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"dna">>,              maps:get(<<"phase">>, Map)).

start_invalid_phase() ->
    {ok, Cmd} = start_phase_v1:new(#{
        division_id => <<"div-1">>,
        phase => <<"bogus">>
    }),
    %% Command-level validate catches invalid phase names
    {error, invalid_phase} = start_phase_v1:validate(Cmd).

start_empty_division_id() ->
    {ok, Cmd} = start_phase_v1:new(#{
        division_id => <<>>,
        phase => <<"dna">>
    }),
    %% Handler validate_command rejects empty division_id
    {error, _} = maybe_start_phase:handle(Cmd).

%% --- pause_phase ---

pause_valid() ->
    {ok, Cmd} = pause_phase_v1:from_map(#{
        <<"division_id">> => <<"div-1">>,
        <<"phase">> => <<"dna">>,
        <<"reason">> => <<"blocked">>
    }),
    {ok, [Event]} = maybe_pause_phase:handle(Cmd),
    Map = phase_paused_v1:to_map(Event),
    ?assertEqual(<<"phase_paused_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"blocked">>,         maps:get(<<"reason">>, Map)).

pause_empty_id() ->
    {ok, Cmd} = pause_phase_v1:from_map(#{
        <<"division_id">> => <<>>,
        <<"phase">> => <<"dna">>,
        <<"reason">> => <<"blocked">>
    }),
    {error, _} = maybe_pause_phase:handle(Cmd).

%% --- resume_phase ---

resume_valid() ->
    {ok, Cmd} = resume_phase_v1:from_map(#{
        <<"division_id">> => <<"div-1">>,
        <<"phase">> => <<"dna">>
    }),
    {ok, [Event]} = maybe_resume_phase:handle(Cmd),
    Map = phase_resumed_v1:to_map(Event),
    ?assertEqual(<<"phase_resumed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>,            maps:get(<<"division_id">>, Map)).

resume_empty_id() ->
    {ok, Cmd} = resume_phase_v1:from_map(#{
        <<"division_id">> => <<>>,
        <<"phase">> => <<"dna">>
    }),
    {error, _} = maybe_resume_phase:handle(Cmd).

%% --- complete_phase ---

complete_valid() ->
    {ok, Cmd} = complete_phase_v1:from_map(#{
        <<"division_id">> => <<"div-1">>,
        <<"phase">> => <<"dna">>
    }),
    {ok, [Event]} = maybe_complete_phase:handle(Cmd),
    Map = phase_completed_v1:to_map(Event),
    ?assertEqual(<<"phase_completed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"dna">>,                maps:get(<<"phase">>, Map)).

complete_empty_id() ->
    {ok, Cmd} = complete_phase_v1:from_map(#{
        <<"division_id">> => <<>>,
        <<"phase">> => <<"dna">>
    }),
    {error, _} = maybe_complete_phase:handle(Cmd).
