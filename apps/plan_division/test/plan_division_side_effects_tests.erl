%%% @doc Layer 4: Side Effect Tests -- pg emission and message format.
%%% Tests that emitters correctly broadcast to pg group members
%%% with the expected message format.
-module(plan_division_side_effects_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test suite with pg scope setup/teardown
%% ===================================================================

pg_emission_test_() ->
    {setup,
     fun start_pg/0,
     fun stop_pg/1,
     [
      fun emit_plan_started_reaches_members/0,
      fun emit_plan_started_message_format/0,
      fun emit_desk_planned_reaches_members/0,
      fun emit_dependency_planned_reaches_members/0,
      fun emit_plan_paused_reaches_members/0,
      fun emit_plan_resumed_reaches_members/0,
      fun emit_plan_completed_reaches_members/0,
      fun emit_plan_archived_reaches_members/0,
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

%% plan_started_v1_to_pg:emit/1 reaches a joined member
emit_plan_started_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, plan_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"plan_started_v1">>, <<"division_id">> => <<"d-1">>},
    ok = plan_started_v1_to_pg:emit(Event),
    receive
        {got, Msg} ->
            ?assertEqual({plan_started_v1, Event}, Msg)
    after 1000 ->
        pg:leave(pg, plan_started_v1, Pid),
        ?assert(false)
    end.

%% Message format is {event_atom, EventMap}
emit_plan_started_message_format() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, plan_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"plan_started_v1">>,
              <<"division_id">> => <<"d-fmt">>,
              <<"started_at">> => 1000},
    ok = plan_started_v1_to_pg:emit(Event),
    receive
        {got, {Tag, Payload}} ->
            ?assertEqual(plan_started_v1, Tag),
            ?assert(is_map(Payload)),
            ?assertEqual(<<"d-fmt">>, maps:get(<<"division_id">>, Payload))
    after 1000 ->
        pg:leave(pg, plan_started_v1, Pid),
        ?assert(false)
    end.

%% desk_planned_v1_to_pg
emit_desk_planned_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, desk_planned_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"desk_planned_v1">>,
              <<"division_id">> => <<"d-desk">>,
              <<"desk_name">> => <<"register_user">>},
    ok = desk_planned_v1_to_pg:emit(Event),
    receive
        {got, {desk_planned_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, desk_planned_v1, Pid),
        ?assert(false)
    end.

%% dependency_planned_v1_to_pg
emit_dependency_planned_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, dependency_planned_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"dependency_planned_v1">>,
              <<"division_id">> => <<"d-dep">>,
              <<"dependency_id">> => <<"dep-001">>},
    ok = dependency_planned_v1_to_pg:emit(Event),
    receive
        {got, {dependency_planned_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, dependency_planned_v1, Pid),
        ?assert(false)
    end.

%% plan_paused_v1_to_pg
emit_plan_paused_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, plan_paused_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"plan_paused_v1">>,
              <<"division_id">> => <<"d-pause">>,
              <<"reason">> => <<"review">>},
    ok = plan_paused_v1_to_pg:emit(Event),
    receive
        {got, {plan_paused_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, plan_paused_v1, Pid),
        ?assert(false)
    end.

%% plan_resumed_v1_to_pg
emit_plan_resumed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, plan_resumed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"plan_resumed_v1">>,
              <<"division_id">> => <<"d-resume">>},
    ok = plan_resumed_v1_to_pg:emit(Event),
    receive
        {got, {plan_resumed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, plan_resumed_v1, Pid),
        ?assert(false)
    end.

%% plan_completed_v1_to_pg
emit_plan_completed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, plan_completed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"plan_completed_v1">>,
              <<"division_id">> => <<"d-complete">>},
    ok = plan_completed_v1_to_pg:emit(Event),
    receive
        {got, {plan_completed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, plan_completed_v1, Pid),
        ?assert(false)
    end.

%% plan_archived_v1_to_pg
emit_plan_archived_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, plan_archived_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"plan_archived_v1">>,
              <<"division_id">> => <<"d-archive">>,
              <<"reason">> => <<"obsolete">>},
    ok = plan_archived_v1_to_pg:emit(Event),
    receive
        {got, {plan_archived_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, plan_archived_v1, Pid),
        ?assert(false)
    end.

%% Emitting with no members does not crash
emit_with_no_members() ->
    %% Ensure no members in an unused group
    Event = #{<<"event_type">> => <<"plan_started_v1">>, <<"division_id">> => <<"d-empty">>},
    ?assertEqual(ok, plan_started_v1_to_pg:emit(Event)).

%% Emitting reaches all members (broadcast)
emit_reaches_multiple_members() ->
    Self = self(),
    Group = plan_started_v1,
    Pids = [spawn_link(fun() ->
        pg:join(pg, Group, self()),
        receive Msg -> Self ! {got, self(), Msg} end
    end) || _ <- lists:seq(1, 3)],
    timer:sleep(20),
    Event = #{<<"event_type">> => <<"plan_started_v1">>, <<"division_id">> => <<"d-multi">>},
    ok = plan_started_v1_to_pg:emit(Event),
    Results = [receive
        {got, P, Msg} -> {P, Msg}
    after 1000 ->
        timeout
    end || P <- Pids],
    lists:foreach(fun
        ({_Pid, {plan_started_v1, E}}) ->
            ?assertEqual(Event, E);
        (timeout) ->
            ?assert(false)
    end, Results).
