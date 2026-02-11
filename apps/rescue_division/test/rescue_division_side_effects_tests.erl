%%% @doc Layer 4: Side Effect Tests -- pg emission and message format.
%%% Tests that emitters correctly broadcast to pg group members
%%% with the expected message format.
-module(rescue_division_side_effects_tests).

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
      fun emit_diagnosed_reaches_members/0,
      fun emit_fix_applied_reaches_members/0,
      fun emit_paused_reaches_members/0,
      fun emit_resumed_reaches_members/0,
      fun emit_completed_reaches_members/0,
      fun emit_archived_reaches_members/0,
      fun emit_with_no_members/0,
      fun emit_reaches_multiple_members/0
     ]}.

start_pg() ->
    %% pg may already be started by the test runtime
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

%% rescue_started_v1_to_pg:emit/1 reaches a joined member
emit_started_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, rescue_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"rescue_started_v1">>,
              <<"division_id">> => <<"div-1">>,
              <<"incident_id">> => <<"inc-1">>},
    ok = rescue_started_v1_to_pg:emit(Event),
    receive
        {got, Msg} ->
            ?assertEqual({rescue_started_v1, Event}, Msg)
    after 1000 ->
        pg:leave(pg, rescue_started_v1, Pid),
        ?assert(false)
    end.

%% Message format is {event_atom, EventMap}
emit_started_message_format() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, rescue_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"rescue_started_v1">>,
              <<"division_id">> => <<"div-fmt">>,
              <<"incident_id">> => <<"inc-fmt">>},
    ok = rescue_started_v1_to_pg:emit(Event),
    receive
        {got, {Tag, Payload}} ->
            ?assertEqual(rescue_started_v1, Tag),
            ?assert(is_map(Payload)),
            ?assertEqual(<<"div-fmt">>, maps:get(<<"division_id">>, Payload))
    after 1000 ->
        pg:leave(pg, rescue_started_v1, Pid),
        ?assert(false)
    end.

%% incident_diagnosed_v1_to_pg
emit_diagnosed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, incident_diagnosed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"incident_diagnosed_v1">>,
              <<"division_id">> => <<"div-d">>,
              <<"diagnosis_id">> => <<"diag-1">>},
    ok = incident_diagnosed_v1_to_pg:emit(Event),
    receive
        {got, {incident_diagnosed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, incident_diagnosed_v1, Pid),
        ?assert(false)
    end.

%% fix_applied_v1_to_pg
emit_fix_applied_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, fix_applied_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"fix_applied_v1">>,
              <<"division_id">> => <<"div-f">>,
              <<"fix_id">> => <<"fix-1">>},
    ok = fix_applied_v1_to_pg:emit(Event),
    receive
        {got, {fix_applied_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, fix_applied_v1, Pid),
        ?assert(false)
    end.

%% rescue_paused_v1_to_pg
emit_paused_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, rescue_paused_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"rescue_paused_v1">>,
              <<"division_id">> => <<"div-p">>},
    ok = rescue_paused_v1_to_pg:emit(Event),
    receive
        {got, {rescue_paused_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, rescue_paused_v1, Pid),
        ?assert(false)
    end.

%% rescue_resumed_v1_to_pg
emit_resumed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, rescue_resumed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"rescue_resumed_v1">>,
              <<"division_id">> => <<"div-r">>},
    ok = rescue_resumed_v1_to_pg:emit(Event),
    receive
        {got, {rescue_resumed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, rescue_resumed_v1, Pid),
        ?assert(false)
    end.

%% rescue_completed_v1_to_pg
emit_completed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, rescue_completed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"rescue_completed_v1">>,
              <<"division_id">> => <<"div-c">>},
    ok = rescue_completed_v1_to_pg:emit(Event),
    receive
        {got, {rescue_completed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, rescue_completed_v1, Pid),
        ?assert(false)
    end.

%% rescue_archived_v1_to_pg
emit_archived_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, rescue_archived_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"rescue_archived_v1">>,
              <<"division_id">> => <<"div-a">>},
    ok = rescue_archived_v1_to_pg:emit(Event),
    receive
        {got, {rescue_archived_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, rescue_archived_v1, Pid),
        ?assert(false)
    end.

%% Emitting with no members does not crash
emit_with_no_members() ->
    Event = #{<<"event_type">> => <<"rescue_started_v1">>,
              <<"division_id">> => <<"div-empty">>},
    ?assertEqual(ok, rescue_started_v1_to_pg:emit(Event)).

%% Emitting reaches all members (broadcast)
emit_reaches_multiple_members() ->
    Self = self(),
    Group = rescue_started_v1,
    Pids = [spawn_link(fun() ->
        pg:join(pg, Group, self()),
        receive Msg -> Self ! {got, self(), Msg} end
    end) || _ <- lists:seq(1, 3)],
    timer:sleep(20),
    Event = #{<<"event_type">> => <<"rescue_started_v1">>,
              <<"division_id">> => <<"div-multi">>},
    ok = rescue_started_v1_to_pg:emit(Event),
    Results = [receive
        {got, P, Msg} -> {P, Msg}
    after 1000 ->
        timeout
    end || P <- Pids],
    lists:foreach(fun
        ({_Pid, {rescue_started_v1, E}}) ->
            ?assertEqual(Event, E);
        (timeout) ->
            ?assert(false)
    end, Results).
