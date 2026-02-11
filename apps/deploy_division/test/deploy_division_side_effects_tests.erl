%%% @doc Layer 4: Side Effect Tests — pg emission and message format.
%%% Tests that emitters correctly broadcast to pg group members
%%% with the expected message format.
-module(deploy_division_side_effects_tests).

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
      fun emit_release_deployed_reaches_members/0,
      fun emit_rollout_staged_reaches_members/0,
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

%% deployment_started_v1_to_pg:emit/1 reaches a joined member
emit_started_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, deployment_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"deployment_started_v1">>,
              <<"division_id">> => <<"div-1">>},
    ok = deployment_started_v1_to_pg:emit(Event),
    receive
        {got, Msg} ->
            ?assertEqual({deployment_started_v1, Event}, Msg)
    after 1000 ->
        pg:leave(pg, deployment_started_v1, Pid),
        ?assert(false)
    end.

%% Message format is {event_atom, EventMap}
emit_started_message_format() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, deployment_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"deployment_started_v1">>,
              <<"division_id">> => <<"div-fmt">>,
              <<"started_at">> => 1000},
    ok = deployment_started_v1_to_pg:emit(Event),
    receive
        {got, {Tag, Payload}} ->
            ?assertEqual(deployment_started_v1, Tag),
            ?assert(is_map(Payload)),
            ?assertEqual(<<"div-fmt">>, maps:get(<<"division_id">>, Payload))
    after 1000 ->
        pg:leave(pg, deployment_started_v1, Pid),
        ?assert(false)
    end.

%% release_deployed_v1_to_pg
emit_release_deployed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, release_deployed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"release_deployed_v1">>,
              <<"division_id">> => <<"div-r">>},
    ok = release_deployed_v1_to_pg:emit(Event),
    receive
        {got, {release_deployed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, release_deployed_v1, Pid),
        ?assert(false)
    end.

%% rollout_staged_v1_to_pg
emit_rollout_staged_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, rollout_staged_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"rollout_staged_v1">>,
              <<"division_id">> => <<"div-s">>},
    ok = rollout_staged_v1_to_pg:emit(Event),
    receive
        {got, {rollout_staged_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, rollout_staged_v1, Pid),
        ?assert(false)
    end.

%% deployment_paused_v1_to_pg
emit_paused_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, deployment_paused_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"deployment_paused_v1">>,
              <<"division_id">> => <<"div-p">>},
    ok = deployment_paused_v1_to_pg:emit(Event),
    receive
        {got, {deployment_paused_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, deployment_paused_v1, Pid),
        ?assert(false)
    end.

%% deployment_resumed_v1_to_pg
emit_resumed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, deployment_resumed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"deployment_resumed_v1">>,
              <<"division_id">> => <<"div-res">>},
    ok = deployment_resumed_v1_to_pg:emit(Event),
    receive
        {got, {deployment_resumed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, deployment_resumed_v1, Pid),
        ?assert(false)
    end.

%% deployment_completed_v1_to_pg
emit_completed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, deployment_completed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"deployment_completed_v1">>,
              <<"division_id">> => <<"div-c">>},
    ok = deployment_completed_v1_to_pg:emit(Event),
    receive
        {got, {deployment_completed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, deployment_completed_v1, Pid),
        ?assert(false)
    end.

%% deployment_archived_v1_to_pg
emit_archived_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, deployment_archived_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"deployment_archived_v1">>,
              <<"division_id">> => <<"div-a">>},
    ok = deployment_archived_v1_to_pg:emit(Event),
    receive
        {got, {deployment_archived_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, deployment_archived_v1, Pid),
        ?assert(false)
    end.

%% Emitting with no members does not crash
emit_with_no_members() ->
    Event = #{<<"event_type">> => <<"deployment_started_v1">>,
              <<"division_id">> => <<"div-empty">>},
    ?assertEqual(ok, deployment_started_v1_to_pg:emit(Event)).

%% Emitting reaches all members (broadcast)
emit_reaches_multiple_members() ->
    Self = self(),
    Group = deployment_started_v1,
    Pids = [spawn_link(fun() ->
        pg:join(pg, Group, self()),
        receive Msg -> Self ! {got, self(), Msg} end
    end) || _ <- lists:seq(1, 3)],
    timer:sleep(20),
    Event = #{<<"event_type">> => <<"deployment_started_v1">>,
              <<"division_id">> => <<"div-multi">>},
    ok = deployment_started_v1_to_pg:emit(Event),
    Results = [receive
        {got, P, Msg} -> {P, Msg}
    after 1000 ->
        timeout
    end || P <- Pids],
    lists:foreach(fun
        ({_Pid, {deployment_started_v1, E}}) ->
            ?assertEqual(Event, E);
        (timeout) ->
            ?assert(false)
    end, Results).
