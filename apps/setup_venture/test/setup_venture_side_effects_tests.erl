%%% @doc Layer 4: Side Effect Tests — pg emission and message format.
%%% Tests that emitters correctly broadcast to pg group members
%%% with the expected message format.
-module(setup_venture_side_effects_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test suite with pg scope setup/teardown
%% ===================================================================

pg_emission_test_() ->
    {setup,
     fun start_pg/0,
     fun stop_pg/1,
     [
      fun emit_setup_reaches_members/0,
      fun emit_setup_message_format/0,
      fun emit_refine_reaches_members/0,
      fun emit_submit_reaches_members/0,
      fun emit_archive_reaches_members/0,
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

%% venture_setup_v1_to_pg:emit/1 reaches a joined member
emit_setup_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, venture_setup_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    %% Wait for join to complete
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"venture_setup_v1">>, <<"venture_id">> => <<"v-1">>},
    ok = venture_setup_v1_to_pg:emit(Event),
    receive
        {got, Msg} ->
            ?assertEqual({venture_setup_v1, Event}, Msg)
    after 1000 ->
        pg:leave(pg, venture_setup_v1, Pid),
        ?assert(false)
    end.

%% Message format is {event_atom, EventMap}
emit_setup_message_format() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, venture_setup_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"venture_setup_v1">>,
              <<"venture_id">> => <<"v-fmt">>,
              <<"name">> => <<"Test">>},
    ok = venture_setup_v1_to_pg:emit(Event),
    receive
        {got, {Tag, Payload}} ->
            ?assertEqual(venture_setup_v1, Tag),
            ?assert(is_map(Payload)),
            ?assertEqual(<<"v-fmt">>, maps:get(<<"venture_id">>, Payload))
    after 1000 ->
        pg:leave(pg, venture_setup_v1, Pid),
        ?assert(false)
    end.

%% venture_vision_refined_v1_to_pg
emit_refine_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, venture_vision_refined_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"venture_vision_refined_v1">>, <<"venture_id">> => <<"v-r">>},
    ok = venture_vision_refined_v1_to_pg:emit(Event),
    receive
        {got, {venture_vision_refined_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, venture_vision_refined_v1, Pid),
        ?assert(false)
    end.

%% venture_vision_submitted_v1_to_pg
emit_submit_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, venture_vision_submitted_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"venture_vision_submitted_v1">>, <<"venture_id">> => <<"v-s">>},
    ok = venture_vision_submitted_v1_to_pg:emit(Event),
    receive
        {got, {venture_vision_submitted_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, venture_vision_submitted_v1, Pid),
        ?assert(false)
    end.

%% venture_archived_v1_to_pg
emit_archive_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, venture_archived_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"venture_archived_v1">>, <<"venture_id">> => <<"v-a">>},
    ok = venture_archived_v1_to_pg:emit(Event),
    receive
        {got, {venture_archived_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, venture_archived_v1, Pid),
        ?assert(false)
    end.

%% Emitting with no members does not crash
emit_with_no_members() ->
    %% Ensure no members in an unused group
    Event = #{<<"event_type">> => <<"venture_setup_v1">>, <<"venture_id">> => <<"v-empty">>},
    ?assertEqual(ok, venture_setup_v1_to_pg:emit(Event)).

%% Emitting reaches all members (broadcast)
emit_reaches_multiple_members() ->
    Self = self(),
    Group = venture_setup_v1,
    Pids = [spawn_link(fun() ->
        pg:join(pg, Group, self()),
        receive Msg -> Self ! {got, self(), Msg} end
    end) || _ <- lists:seq(1, 3)],
    timer:sleep(20),
    Event = #{<<"event_type">> => <<"venture_setup_v1">>, <<"venture_id">> => <<"v-multi">>},
    ok = venture_setup_v1_to_pg:emit(Event),
    Results = [receive
        {got, P, Msg} -> {P, Msg}
    after 1000 ->
        timeout
    end || P <- Pids],
    lists:foreach(fun
        ({_Pid, {venture_setup_v1, E}}) ->
            ?assertEqual(Event, E);
        (timeout) ->
            ?assert(false)
    end, Results).
