%%% @doc Tests for torch_initiated_v1_to_tui emitter
%%%
%%% Verifies TUI fact broadcasting: torch_initiated_v1 pg events are
%%% JSON-encoded and sent to all tui_connections group members.
%%% @end
-module(torch_initiated_v1_to_tui_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SCOPE, pg).
-define(EVENT_GROUP, torch_initiated_v1).
-define(TUI_GROUP, tui_connections).

%% Test that TUI clients in tui_connections receive {tui_fact, Data}
broadcasts_to_tui_connections_test() ->
    ensure_pg(),

    %% Join tui_connections as a fake TUI client
    ok = pg:join(?SCOPE, ?TUI_GROUP, self()),

    %% Start the emitter gen_server
    {ok, Pid} = torch_initiated_v1_to_tui:start_link(),

    %% Create test event
    Event = #{
        torch_id => <<"tui-test-torch-1">>,
        name => <<"TUI Test Torch">>,
        brief => <<"Testing TUI broadcast">>,
        initiated_at => erlang:system_time(millisecond),
        initiated_by => <<"test-user">>
    },

    %% Send event to the emitter via its pg group
    Pid ! {torch_initiated_v1, Event},

    %% Verify we received a tui_fact
    receive
        {tui_fact, Data} when is_binary(Data) ->
            ?assert(true)
    after 1000 ->
        ?assert(false)
    end,

    %% Cleanup
    gen_server:stop(Pid),
    ok = pg:leave(?SCOPE, ?TUI_GROUP, self()).

%% Test JSON encoding of the fact
json_encoding_correct_test() ->
    ensure_pg(),
    ok = pg:join(?SCOPE, ?TUI_GROUP, self()),
    {ok, Pid} = torch_initiated_v1_to_tui:start_link(),

    Event = #{
        torch_id => <<"json-test-torch">>,
        name => <<"JSON Test">>,
        brief => <<"Check encoding">>,
        initiated_at => 1700000000000,
        initiated_by => <<"encoder">>
    },

    Pid ! {torch_initiated_v1, Event},

    receive
        {tui_fact, Data} ->
            Decoded = json:decode(Data),
            ?assertEqual(<<"torch_initiated_v1">>, maps:get(<<"fact_type">>, Decoded)),
            Inner = maps:get(<<"data">>, Decoded),
            ?assertEqual(<<"json-test-torch">>, maps:get(<<"torch_id">>, Inner)),
            ?assertEqual(<<"JSON Test">>, maps:get(<<"name">>, Inner))
    after 1000 ->
        ?assert(false)
    end,

    gen_server:stop(Pid),
    ok = pg:leave(?SCOPE, ?TUI_GROUP, self()).

%% Test that emitter survives when no TUI clients are connected
no_crash_with_zero_clients_test() ->
    ensure_pg(),

    %% Ensure tui_connections group is empty
    Members = pg:get_members(?SCOPE, ?TUI_GROUP),
    ?assertEqual([], Members),

    {ok, Pid} = torch_initiated_v1_to_tui:start_link(),

    Event = #{torch_id => <<"no-client-test">>, name => <<"No Clients">>},
    Pid ! {torch_initiated_v1, Event},

    %% Give it a moment to process
    timer:sleep(50),

    %% Emitter should still be alive
    ?assert(is_process_alive(Pid)),

    gen_server:stop(Pid).

%% Test that multiple TUI clients all receive the fact
multiple_tui_clients_test() ->
    ensure_pg(),

    Parent = self(),
    Sub1 = spawn_link(fun() -> tui_subscriber_loop(Parent, sub1) end),
    Sub2 = spawn_link(fun() -> tui_subscriber_loop(Parent, sub2) end),

    %% Wait for subscribers to join
    timer:sleep(50),

    {ok, Pid} = torch_initiated_v1_to_tui:start_link(),

    Event = #{torch_id => <<"multi-client-test">>, name => <<"Multi">>},
    Pid ! {torch_initiated_v1, Event},

    %% Collect responses from both subscribers
    Responses = collect_responses(2, 1000),

    ?assertEqual(2, length(Responses)),
    ?assert(lists:member(sub1, [Tag || {Tag, _} <- Responses])),
    ?assert(lists:member(sub2, [Tag || {Tag, _} <- Responses])),

    gen_server:stop(Pid),
    exit(Sub1, normal),
    exit(Sub2, normal).

%%% ===================================================================
%%% Helpers
%%% ===================================================================

ensure_pg() ->
    case pg:start(?SCOPE) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.

tui_subscriber_loop(Parent, Tag) ->
    ok = pg:join(?SCOPE, ?TUI_GROUP, self()),
    receive
        {tui_fact, Data} ->
            Parent ! {received, Tag, Data}
    end.

collect_responses(0, _Timeout) ->
    [];
collect_responses(N, Timeout) ->
    receive
        {received, Tag, Data} ->
            [{Tag, Data} | collect_responses(N - 1, Timeout)]
    after Timeout ->
        []
    end.
