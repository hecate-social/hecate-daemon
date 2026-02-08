%%% @doc Tests for torch_initiated_v1_to_pg emitter
-module(torch_initiated_v1_to_pg_tests).

-include_lib("eunit/include/eunit.hrl").

-define(GROUP, torch_initiated_v1).
-define(SCOPE, pg).

%% Test that emit broadcasts to pg group
emit_broadcasts_to_group_test() ->
    %% Ensure pg is started
    ensure_pg(),

    %% Join the group to receive the event
    ok = pg:join(?SCOPE, ?GROUP, self()),

    %% Create test event
    Event = #{
        torch_id => <<"test-torch-123">>,
        name => <<"Test Torch">>,
        brief => <<"A test torch">>,
        initiated_at => erlang:system_time(millisecond),
        initiated_by => <<"test-user">>
    },

    %% Emit the event
    ok = torch_initiated_v1_to_pg:emit(Event),

    %% Verify we received it
    receive
        {torch_initiated_v1, ReceivedEvent} ->
            ?assertEqual(Event, ReceivedEvent)
    after 1000 ->
        ?assert(false, "Did not receive event within timeout")
    end,

    %% Cleanup
    ok = pg:leave(?SCOPE, ?GROUP, self()).

%% Test that multiple subscribers receive the event
multiple_subscribers_test() ->
    ensure_pg(),

    %% Spawn two subscriber processes
    Parent = self(),
    Subscriber1 = spawn_link(fun() -> subscriber_loop(Parent, sub1) end),
    Subscriber2 = spawn_link(fun() -> subscriber_loop(Parent, sub2) end),

    %% Wait for them to join
    timer:sleep(50),

    %% Emit event
    Event = #{torch_id => <<"multi-test">>, name => <<"Multi">>},
    ok = torch_initiated_v1_to_pg:emit(Event),

    %% Collect responses
    Responses = collect_responses(2, 1000),

    ?assertEqual(2, length(Responses)),
    ?assert(lists:member({sub1, Event}, Responses)),
    ?assert(lists:member({sub2, Event}, Responses)),

    %% Cleanup
    exit(Subscriber1, normal),
    exit(Subscriber2, normal).

%% Internal helpers

ensure_pg() ->
    case pg:start(?SCOPE) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.

subscriber_loop(Parent, Tag) ->
    ok = pg:join(?SCOPE, ?GROUP, self()),
    receive
        {torch_initiated_v1, Event} ->
            Parent ! {received, Tag, Event}
    end.

collect_responses(0, _Timeout) ->
    [];
collect_responses(N, Timeout) ->
    receive
        {received, Tag, Event} ->
            [{Tag, Event} | collect_responses(N - 1, Timeout)]
    after Timeout ->
        []
    end.
