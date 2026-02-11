%%% @doc Layer 2b+2c: Handler + Aggregate execute/2 tests.
%%% Tests handle/1,2 business logic and execute/2 state machine guards.
%%% No I/O -- builds state via apply/2 chains, then tests commands.
%%%
%%% This app has 8 commands/events. Domain commands (register_health_check,
%%% record_health_status, raise_incident) require context maps.
-module(monitor_division_handler_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("monitor_division/include/monitoring_status.hrl").

%% Record field positions in monitoring_state
-define(F_DIVISION_ID,   2).
-define(F_STATUS,        3).
-define(F_HEALTH_CHECKS, 4).
-define(F_INCIDENTS,     5).

%% ===================================================================
%% Helpers: build state from event sequence
%% ===================================================================

fresh_state() ->
    {ok, S} = monitoring_aggregate:init(<<"div-1">>),
    S.

started_state() ->
    monitoring_aggregate:apply(fresh_state(), start_event_map()).

paused_state() ->
    monitoring_aggregate:apply(started_state(), pause_event_map()).

completed_state() ->
    monitoring_aggregate:apply(started_state(), complete_event_map()).

archived_state() ->
    monitoring_aggregate:apply(started_state(), archive_event_map()).

%% Started state with one health check registered
started_with_check_state() ->
    monitoring_aggregate:apply(started_state(), health_check_registered_event_map()).

start_event_map() ->
    #{<<"event_type">> => <<"monitoring_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

health_check_registered_event_map() ->
    #{<<"event_type">> => <<"health_check_registered_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"check_id">> => <<"check-div-1-api">>,
      <<"check_name">> => <<"api">>,
      <<"check_type">> => <<"http">>,
      <<"endpoint">> => <<"https://api.example.com/health">>,
      <<"interval_ms">> => 30000,
      <<"registered_at">> => 1100}.

pause_event_map() ->
    #{<<"event_type">> => <<"monitoring_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 2000,
      <<"reason">> => <<"maintenance">>}.

complete_event_map() ->
    #{<<"event_type">> => <<"monitoring_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 3000}.

archive_event_map() ->
    #{<<"event_type">> => <<"monitoring_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 4000}.

%% ===================================================================
%% Layer 2b: Handler Tests (Business Logic)
%% ===================================================================

%% --- maybe_start_monitoring ---

handle_valid_start_test() ->
    {ok, Cmd} = start_monitoring_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_start_monitoring:handle(Cmd),
    Map = monitoring_started_v1:to_map(Event),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"user@host">>, maps:get(<<"started_by">>, Map)),
    ?assert(is_integer(maps:get(<<"started_at">>, Map))).

handle_start_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 start_monitoring_v1:new(#{division_id => <<>>})).

%% --- maybe_register_health_check ---

handle_valid_register_health_check_test() ->
    {ok, Cmd} = register_health_check_v1:new(#{
        division_id => <<"div-1">>,
        check_name => <<"api">>,
        check_type => <<"http">>,
        endpoint => <<"https://api.example.com/health">>,
        interval_ms => 15000
    }),
    Context = #{health_checks => #{}},
    {ok, [Event]} = maybe_register_health_check:handle(Cmd, Context),
    Map = health_check_registered_v1:to_map(Event),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"check-div-1-api">>, maps:get(<<"check_id">>, Map)),
    ?assertEqual(<<"api">>, maps:get(<<"check_name">>, Map)),
    ?assertEqual(<<"http">>, maps:get(<<"check_type">>, Map)),
    ?assertEqual(<<"https://api.example.com/health">>, maps:get(<<"endpoint">>, Map)),
    ?assertEqual(15000, maps:get(<<"interval_ms">>, Map)).

handle_register_health_check_already_exists_test() ->
    {ok, Cmd} = register_health_check_v1:new(#{
        division_id => <<"div-1">>,
        check_name => <<"api">>
    }),
    Context = #{health_checks => #{<<"check-div-1-api">> => #{}}},
    ?assertEqual({error, health_check_already_registered},
                 maybe_register_health_check:handle(Cmd, Context)).

handle_register_health_check_invalid_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 register_health_check_v1:new(#{division_id => <<>>, check_name => <<"x">>})).

handle_register_health_check_invalid_name_test() ->
    ?assertEqual({error, {invalid_field, check_name}},
                 register_health_check_v1:new(#{division_id => <<"d">>, check_name => <<>>})).

%% --- maybe_record_health_status ---

handle_valid_record_health_status_test() ->
    {ok, Cmd} = record_health_status_v1:new(#{
        division_id => <<"div-1">>,
        check_id => <<"check-div-1-api">>,
        status => <<"healthy">>,
        latency_ms => 42,
        details => <<"200 OK">>
    }),
    Context = #{health_checks => #{<<"check-div-1-api">> => #{}}},
    {ok, [Event]} = maybe_record_health_status:handle(Cmd, Context),
    Map = health_status_recorded_v1:to_map(Event),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"check-div-1-api">>, maps:get(<<"check_id">>, Map)),
    ?assertEqual(<<"healthy">>, maps:get(<<"status">>, Map)),
    ?assertEqual(42, maps:get(<<"latency_ms">>, Map)),
    ?assertEqual(<<"200 OK">>, maps:get(<<"details">>, Map)).

handle_record_health_status_check_not_found_test() ->
    {ok, Cmd} = record_health_status_v1:new(#{
        division_id => <<"div-1">>,
        check_id => <<"check-nonexistent">>
    }),
    Context = #{health_checks => #{}},
    ?assertEqual({error, health_check_not_found},
                 maybe_record_health_status:handle(Cmd, Context)).

handle_record_health_status_invalid_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 record_health_status_v1:new(#{division_id => <<>>, check_id => <<"c">>})).

handle_record_health_status_invalid_check_id_test() ->
    ?assertEqual({error, {invalid_field, check_id}},
                 record_health_status_v1:new(#{division_id => <<"d">>, check_id => <<>>})).

%% --- maybe_raise_incident ---

handle_valid_raise_incident_test() ->
    {ok, Cmd} = raise_incident_v1:new(#{
        division_id => <<"div-1">>,
        incident_title => <<"API Down">>,
        severity => <<"high">>,
        description => <<"Multiple health check failures">>
    }),
    {ok, [Event]} = maybe_raise_incident:handle(Cmd),
    Map = incident_raised_v1:to_map(Event),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"API Down">>, maps:get(<<"incident_title">>, Map)),
    ?assertEqual(<<"high">>, maps:get(<<"severity">>, Map)),
    ?assertEqual(<<"Multiple health check failures">>, maps:get(<<"description">>, Map)),
    ?assert(is_binary(maps:get(<<"incident_id">>, Map))).

handle_raise_incident_invalid_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 raise_incident_v1:new(#{division_id => <<>>, incident_title => <<"X">>})).

handle_raise_incident_invalid_title_test() ->
    ?assertEqual({error, {invalid_field, incident_title}},
                 raise_incident_v1:new(#{division_id => <<"d">>, incident_title => <<>>})).

%% --- maybe_pause_monitoring ---

handle_valid_pause_test() ->
    {ok, Cmd} = pause_monitoring_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"maintenance window">>
    }),
    {ok, [Event]} = maybe_pause_monitoring:handle(Cmd),
    Map = monitoring_paused_v1:to_map(Event),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"maintenance window">>, maps:get(<<"reason">>, Map)),
    ?assert(is_integer(maps:get(<<"paused_at">>, Map))).

handle_pause_invalid_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 pause_monitoring_v1:new(#{division_id => <<>>})).

%% --- maybe_resume_monitoring ---

handle_valid_resume_test() ->
    {ok, Cmd} = resume_monitoring_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_resume_monitoring:handle(Cmd),
    Map = monitoring_resumed_v1:to_map(Event),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assert(is_integer(maps:get(<<"resumed_at">>, Map))).

handle_resume_invalid_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 resume_monitoring_v1:new(#{division_id => <<>>})).

%% --- maybe_complete_monitoring ---

handle_valid_complete_test() ->
    {ok, Cmd} = complete_monitoring_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_complete_monitoring:handle(Cmd),
    Map = monitoring_completed_v1:to_map(Event),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assert(is_integer(maps:get(<<"completed_at">>, Map))).

handle_complete_invalid_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 complete_monitoring_v1:new(#{division_id => <<>>})).

%% --- maybe_archive_monitoring ---

handle_valid_archive_test() ->
    {ok, Cmd} = archive_monitoring_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    {ok, [Event]} = maybe_archive_monitoring:handle(Cmd),
    Map = monitoring_archived_v1:to_map(Event),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)),
    ?assert(is_integer(maps:get(<<"archived_at">>, Map))).

handle_archive_invalid_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 archive_monitoring_v1:new(#{division_id => <<>>})).

%% ===================================================================
%% Layer 2c: Aggregate execute/2 State Machine Tests
%% ===================================================================

%% --- start_monitoring command ---

execute_start_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"start_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(fresh_state(), Cmd),
    ?assertEqual(<<"monitoring_started_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_start_already_started_test() ->
    Cmd = #{<<"command_type">> => <<"start_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    %% After start, status is INITIATED|ACTIVE, not 0, so the first clause
    %% won't match -- falls through to execute_lifecycle which returns unknown_command
    Result = monitoring_aggregate:execute(started_state(), Cmd),
    ?assertMatch({error, _}, Result).

%% --- register_health_check command ---

execute_register_health_check_when_active_test() ->
    Cmd = #{<<"command_type">> => <<"register_health_check">>,
            <<"division_id">> => <<"div-1">>,
            <<"check_name">> => <<"api">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"health_check_registered_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_register_health_check_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"register_health_check">>,
            <<"division_id">> => <<"div-1">>,
            <<"check_name">> => <<"api">>},
    Status = element(?F_STATUS, paused_state()),
    ?assertEqual({error, {not_active, Status}},
                 monitoring_aggregate:execute(paused_state(), Cmd)).

execute_register_health_check_when_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"register_health_check">>,
            <<"division_id">> => <<"div-1">>,
            <<"check_name">> => <<"api">>},
    ?assertEqual({error, monitoring_not_started},
                 monitoring_aggregate:execute(fresh_state(), Cmd)).

%% --- record_health_status command ---

execute_record_health_status_when_active_test() ->
    Cmd = #{<<"command_type">> => <<"record_health_status">>,
            <<"division_id">> => <<"div-1">>,
            <<"check_id">> => <<"check-div-1-api">>,
            <<"status">> => <<"healthy">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(started_with_check_state(), Cmd),
    ?assertEqual(<<"health_status_recorded_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_record_health_status_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"record_health_status">>,
            <<"division_id">> => <<"div-1">>,
            <<"check_id">> => <<"check-div-1-api">>},
    Status = element(?F_STATUS, paused_state()),
    ?assertEqual({error, {not_active, Status}},
                 monitoring_aggregate:execute(paused_state(), Cmd)).

%% --- raise_incident command ---

execute_raise_incident_when_active_test() ->
    Cmd = #{<<"command_type">> => <<"raise_incident">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_title">> => <<"API Down">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"incident_raised_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_raise_incident_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"raise_incident">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_title">> => <<"API Down">>},
    Status = element(?F_STATUS, paused_state()),
    ?assertEqual({error, {not_active, Status}},
                 monitoring_aggregate:execute(paused_state(), Cmd)).

%% --- pause_monitoring command ---

execute_pause_when_active_test() ->
    Cmd = #{<<"command_type">> => <<"pause_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"monitoring_paused_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_pause_when_already_paused_test() ->
    Cmd = #{<<"command_type">> => <<"pause_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    Status = element(?F_STATUS, paused_state()),
    ?assertEqual({error, {not_active, Status}},
                 monitoring_aggregate:execute(paused_state(), Cmd)).

execute_pause_when_completed_test() ->
    Cmd = #{<<"command_type">> => <<"pause_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    Status = element(?F_STATUS, completed_state()),
    ?assertEqual({error, {not_active, Status}},
                 monitoring_aggregate:execute(completed_state(), Cmd)).

%% --- resume_monitoring command ---

execute_resume_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"resume_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"monitoring_resumed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_resume_when_active_test() ->
    Cmd = #{<<"command_type">> => <<"resume_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    Status = element(?F_STATUS, started_state()),
    ?assertEqual({error, {not_paused, Status}},
                 monitoring_aggregate:execute(started_state(), Cmd)).

execute_resume_when_completed_test() ->
    Cmd = #{<<"command_type">> => <<"resume_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    Status = element(?F_STATUS, completed_state()),
    ?assertEqual({error, {not_paused, Status}},
                 monitoring_aggregate:execute(completed_state(), Cmd)).

%% --- complete_monitoring command ---

execute_complete_when_active_test() ->
    Cmd = #{<<"command_type">> => <<"complete_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"monitoring_completed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_complete_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"complete_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    Status = element(?F_STATUS, paused_state()),
    ?assertEqual({error, {not_active, Status}},
                 monitoring_aggregate:execute(paused_state(), Cmd)).

execute_complete_when_already_completed_test() ->
    Cmd = #{<<"command_type">> => <<"complete_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    Status = element(?F_STATUS, completed_state()),
    ?assertEqual({error, {not_active, Status}},
                 monitoring_aggregate:execute(completed_state(), Cmd)).

%% --- archive_monitoring command ---

execute_archive_when_active_test() ->
    Cmd = #{<<"command_type">> => <<"archive_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"monitoring_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_when_completed_test() ->
    Cmd = #{<<"command_type">> => <<"archive_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(completed_state(), Cmd),
    ?assertEqual(<<"monitoring_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_when_paused_test() ->
    Cmd = #{<<"command_type">> => <<"archive_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = monitoring_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"monitoring_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"archive_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, monitoring_not_started},
                 monitoring_aggregate:execute(fresh_state(), Cmd)).

execute_archive_already_archived_test() ->
    Cmd = #{<<"command_type">> => <<"archive_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, monitoring_archived},
                 monitoring_aggregate:execute(archived_state(), Cmd)).

%% --- unknown command ---

execute_unknown_command_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, unknown_command},
                 monitoring_aggregate:execute(started_state(), Cmd)).

%% --- evoq callback order: execute(State, Payload) ---

execute_evoq_callback_order_test() ->
    State = fresh_state(),
    Payload = #{<<"command_type">> => <<"start_monitoring">>,
                <<"division_id">> => <<"div-order">>},
    {ok, _Events} = monitoring_aggregate:execute(State, Payload).
