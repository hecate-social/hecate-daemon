%%% @doc Layer 4: Side Effect Tests -- pg emission and message format.
%%% Tests that emitters correctly broadcast to pg group members
%%% with the expected message format.
%%% All 8 pg emitters for the monitor_division app.
-module(monitor_division_side_effects_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test suite with pg scope setup/teardown
%% ===================================================================

pg_emission_test_() ->
    {setup,
     fun start_pg/0,
     fun stop_pg/1,
     [
      fun emit_started_reaches_members/0,
      fun emit_started_message_format/0,
      fun emit_health_check_registered_reaches_members/0,
      fun emit_health_status_recorded_reaches_members/0,
      fun emit_incident_raised_reaches_members/0,
      fun emit_paused_reaches_members/0,
      fun emit_resumed_reaches_members/0,
      fun emit_completed_reaches_members/0,
      fun emit_archived_reaches_members/0,
      fun emit_with_no_members/0,
      fun emit_reaches_multiple_members/0
     ]}.

start_pg() ->
    case pg:start(pg) of
        {ok, Pid} -> {started, Pid};
        {error, {already_started, Pid}} -> {existing, Pid}
    end.

stop_pg({started, Pid}) ->
    gen_server:stop(Pid);
stop_pg({existing, _}) ->
    ok.

%% ===================================================================
%% Test cases
%% ===================================================================

%% monitoring_started_v1_to_pg:emit/1 reaches a joined member
emit_started_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, monitoring_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"monitoring_started_v1">>,
              <<"division_id">> => <<"div-1">>},
    ok = monitoring_started_v1_to_pg:emit(Event),
    receive
        {got, Msg} ->
            ?assertEqual({monitoring_started_v1, Event}, Msg)
    after 1000 ->
        pg:leave(pg, monitoring_started_v1, Pid),
        ?assert(false)
    end.

%% Message format is {event_atom, EventMap}
emit_started_message_format() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, monitoring_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"monitoring_started_v1">>,
              <<"division_id">> => <<"div-fmt">>,
              <<"started_at">> => 1000},
    ok = monitoring_started_v1_to_pg:emit(Event),
    receive
        {got, {Tag, Payload}} ->
            ?assertEqual(monitoring_started_v1, Tag),
            ?assert(is_map(Payload)),
            ?assertEqual(<<"div-fmt">>, maps:get(<<"division_id">>, Payload))
    after 1000 ->
        pg:leave(pg, monitoring_started_v1, Pid),
        ?assert(false)
    end.

%% health_check_registered_v1_to_pg
emit_health_check_registered_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, health_check_registered_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"health_check_registered_v1">>,
              <<"division_id">> => <<"div-hc">>},
    ok = health_check_registered_v1_to_pg:emit(Event),
    receive
        {got, {health_check_registered_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, health_check_registered_v1, Pid),
        ?assert(false)
    end.

%% health_status_recorded_v1_to_pg
emit_health_status_recorded_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, health_status_recorded_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"health_status_recorded_v1">>,
              <<"division_id">> => <<"div-hs">>},
    ok = health_status_recorded_v1_to_pg:emit(Event),
    receive
        {got, {health_status_recorded_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, health_status_recorded_v1, Pid),
        ?assert(false)
    end.

%% incident_raised_v1_to_pg
emit_incident_raised_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, incident_raised_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"incident_raised_v1">>,
              <<"division_id">> => <<"div-ir">>},
    ok = incident_raised_v1_to_pg:emit(Event),
    receive
        {got, {incident_raised_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, incident_raised_v1, Pid),
        ?assert(false)
    end.

%% monitoring_paused_v1_to_pg
emit_paused_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, monitoring_paused_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"monitoring_paused_v1">>,
              <<"division_id">> => <<"div-p">>},
    ok = monitoring_paused_v1_to_pg:emit(Event),
    receive
        {got, {monitoring_paused_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, monitoring_paused_v1, Pid),
        ?assert(false)
    end.

%% monitoring_resumed_v1_to_pg
emit_resumed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, monitoring_resumed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"monitoring_resumed_v1">>,
              <<"division_id">> => <<"div-r">>},
    ok = monitoring_resumed_v1_to_pg:emit(Event),
    receive
        {got, {monitoring_resumed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, monitoring_resumed_v1, Pid),
        ?assert(false)
    end.

%% monitoring_completed_v1_to_pg
emit_completed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, monitoring_completed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"monitoring_completed_v1">>,
              <<"division_id">> => <<"div-c">>},
    ok = monitoring_completed_v1_to_pg:emit(Event),
    receive
        {got, {monitoring_completed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, monitoring_completed_v1, Pid),
        ?assert(false)
    end.

%% monitoring_archived_v1_to_pg
emit_archived_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, monitoring_archived_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"monitoring_archived_v1">>,
              <<"division_id">> => <<"div-a">>},
    ok = monitoring_archived_v1_to_pg:emit(Event),
    receive
        {got, {monitoring_archived_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, monitoring_archived_v1, Pid),
        ?assert(false)
    end.

%% Emitting with no members does not crash
emit_with_no_members() ->
    Event = #{<<"event_type">> => <<"monitoring_started_v1">>,
              <<"division_id">> => <<"div-empty">>},
    ?assertEqual(ok, monitoring_started_v1_to_pg:emit(Event)).

%% Emitting reaches all members (broadcast)
emit_reaches_multiple_members() ->
    Self = self(),
    Group = monitoring_started_v1,
    Pids = [spawn_link(fun() ->
        pg:join(pg, Group, self()),
        receive Msg -> Self ! {got, self(), Msg} end
    end) || _ <- lists:seq(1, 3)],
    timer:sleep(20),
    Event = #{<<"event_type">> => <<"monitoring_started_v1">>,
              <<"division_id">> => <<"div-multi">>},
    ok = monitoring_started_v1_to_pg:emit(Event),
    Results = [receive
        {got, P, Msg} -> {P, Msg}
    after 1000 ->
        timeout
    end || P <- Pids],
    lists:foreach(fun
        ({_Pid, {monitoring_started_v1, E}}) ->
            ?assertEqual(Event, E);
        (timeout) ->
            ?assert(false)
    end, Results).
