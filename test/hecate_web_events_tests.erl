%%% @doc Tests for hecate_web_events broadcast helper
%%% @end
-module(hecate_web_events_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SCOPE, pg).
-define(GROUP, web_connections).

%% Test that broadcast delivers messages to group members
broadcast_delivers_to_members_test() ->
    ensure_pg_scope(),
    ok = pg:join(?SCOPE, ?GROUP, self()),

    hecate_web_events:broadcast(test_event, #{key => <<"value">>}),

    receive
        {web_event, Type, Data} ->
            ?assertEqual(<<"test_event">>, Type),
            Decoded = json:decode(Data),
            ?assertEqual(<<"value">>, maps:get(<<"key">>, Decoded))
    after 1000 ->
        ?assert(false, "Did not receive broadcast message")
    end,

    ok = pg:leave(?SCOPE, ?GROUP, self()).

%% Test that broadcast to empty group succeeds silently
broadcast_empty_group_test() ->
    ensure_pg_scope(),
    %% No members joined — should return ok without error
    ?assertEqual(ok, hecate_web_events:broadcast(no_listeners, #{empty => true})).

%% Test that broadcast sends to multiple members
broadcast_multiple_members_test() ->
    ensure_pg_scope(),

    %% Spawn two receiver processes
    Parent = self(),
    Receiver1 = spawn(fun() ->
        ok = pg:join(?SCOPE, ?GROUP, self()),
        Parent ! {ready, self()},
        receive {web_event, _, _} = Msg -> Parent ! {got, self(), Msg} end
    end),
    Receiver2 = spawn(fun() ->
        ok = pg:join(?SCOPE, ?GROUP, self()),
        Parent ! {ready, self()},
        receive {web_event, _, _} = Msg -> Parent ! {got, self(), Msg} end
    end),

    %% Wait for both to join
    receive {ready, Receiver1} -> ok after 1000 -> error(timeout) end,
    receive {ready, Receiver2} -> ok after 1000 -> error(timeout) end,

    hecate_web_events:broadcast(multi_test, #{n => 2}),

    %% Both should receive the message
    receive {got, Receiver1, {web_event, <<"multi_test">>, _}} -> ok
    after 1000 -> ?assert(false, "Receiver1 did not get message") end,

    receive {got, Receiver2, {web_event, <<"multi_test">>, _}} -> ok
    after 1000 -> ?assert(false, "Receiver2 did not get message") end.

%%% ===================================================================
%%% Helpers
%%% ===================================================================

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.
