%%% @doc Layer 4: Side Effect Tests -- pg emission and message format.
%%% Tests that emitters correctly broadcast to pg group members
%%% with the expected message format.
-module(discover_divisions_side_effects_tests).

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
      fun emit_discovered_reaches_members/0,
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

%% discovery_started_v1_to_pg:emit/1 reaches a joined member
emit_started_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, discovery_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"discovery_started_v1">>,
              <<"venture_id">> => <<"v-1">>},
    ok = discovery_started_v1_to_pg:emit(Event),
    receive
        {got, Msg} ->
            ?assertEqual({discovery_started_v1, Event}, Msg)
    after 1000 ->
        pg:leave(pg, discovery_started_v1, Pid),
        ?assert(false)
    end.

%% Message format is {event_atom, EventMap}
emit_started_message_format() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, discovery_started_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"discovery_started_v1">>,
              <<"venture_id">> => <<"v-fmt">>,
              <<"started_by">> => <<"test">>},
    ok = discovery_started_v1_to_pg:emit(Event),
    receive
        {got, {Tag, Payload}} ->
            ?assertEqual(discovery_started_v1, Tag),
            ?assert(is_map(Payload)),
            ?assertEqual(<<"v-fmt">>, maps:get(<<"venture_id">>, Payload))
    after 1000 ->
        pg:leave(pg, discovery_started_v1, Pid),
        ?assert(false)
    end.

%% division_discovered_v1_to_pg
emit_discovered_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, division_discovered_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"division_discovered_v1">>,
              <<"venture_id">> => <<"v-d">>,
              <<"division_id">> => <<"div-1">>,
              <<"context_name">> => <<"auth">>},
    ok = division_discovered_v1_to_pg:emit(Event),
    receive
        {got, {division_discovered_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, division_discovered_v1, Pid),
        ?assert(false)
    end.

%% discovery_paused_v1_to_pg
emit_paused_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, discovery_paused_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"discovery_paused_v1">>,
              <<"venture_id">> => <<"v-p">>},
    ok = discovery_paused_v1_to_pg:emit(Event),
    receive
        {got, {discovery_paused_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, discovery_paused_v1, Pid),
        ?assert(false)
    end.

%% discovery_resumed_v1_to_pg
emit_resumed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, discovery_resumed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"discovery_resumed_v1">>,
              <<"venture_id">> => <<"v-r">>},
    ok = discovery_resumed_v1_to_pg:emit(Event),
    receive
        {got, {discovery_resumed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, discovery_resumed_v1, Pid),
        ?assert(false)
    end.

%% discovery_completed_v1_to_pg
emit_completed_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, discovery_completed_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"discovery_completed_v1">>,
              <<"venture_id">> => <<"v-c">>},
    ok = discovery_completed_v1_to_pg:emit(Event),
    receive
        {got, {discovery_completed_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, discovery_completed_v1, Pid),
        ?assert(false)
    end.

%% discovery_archived_v1_to_pg
emit_archived_reaches_members() ->
    Self = self(),
    Pid = spawn_link(fun() ->
        pg:join(pg, discovery_archived_v1, self()),
        receive Msg -> Self ! {got, Msg} end
    end),
    timer:sleep(10),
    Event = #{<<"event_type">> => <<"discovery_archived_v1">>,
              <<"venture_id">> => <<"v-a">>},
    ok = discovery_archived_v1_to_pg:emit(Event),
    receive
        {got, {discovery_archived_v1, E}} ->
            ?assertEqual(Event, E)
    after 1000 ->
        pg:leave(pg, discovery_archived_v1, Pid),
        ?assert(false)
    end.

%% Emitting with no members does not crash
emit_with_no_members() ->
    Event = #{<<"event_type">> => <<"discovery_started_v1">>,
              <<"venture_id">> => <<"v-empty">>},
    ?assertEqual(ok, discovery_started_v1_to_pg:emit(Event)).

%% Emitting reaches all members (broadcast)
emit_reaches_multiple_members() ->
    Self = self(),
    Group = discovery_started_v1,
    Pids = [spawn_link(fun() ->
        pg:join(pg, Group, self()),
        receive Msg -> Self ! {got, self(), Msg} end
    end) || _ <- lists:seq(1, 3)],
    timer:sleep(20),
    Event = #{<<"event_type">> => <<"discovery_started_v1">>,
              <<"venture_id">> => <<"v-multi">>},
    ok = discovery_started_v1_to_pg:emit(Event),
    Results = [receive
        {got, P, Msg} -> {P, Msg}
    after 1000 ->
        timeout
    end || P <- Pids],
    lists:foreach(fun
        ({_Pid, {discovery_started_v1, E}}) ->
            ?assertEqual(Event, E);
        (timeout) ->
            ?assert(false)
    end, Results).
