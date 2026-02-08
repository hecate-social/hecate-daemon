%%% @doc Tests for torch_initiated_v1 -> torches projection spoke
-module(torch_initiated_v1_to_torches_tests).

-include_lib("eunit/include/eunit.hrl").

-define(GROUP, torch_initiated_v1).
-define(SCOPE, pg).

%% Setup/teardown for tests that need the full stack
setup() ->
    %% Ensure pg is started
    ensure_pg(),
    %% Start the SQLite store (needed for projection)
    StorePid = case query_torches_store:start_link() of
        {ok, Pid1} -> Pid1;
        {error, {already_started, Pid1}} -> Pid1
    end,
    %% Start the spoke supervisor (starts the listener)
    SupPid = case torch_initiated_v1_to_torches_sup:start_link() of
        {ok, Pid2} -> Pid2;
        {error, {already_started, Pid2}} -> Pid2
    end,
    %% Give listener time to join pg group
    timer:sleep(100),
    {StorePid, SupPid}.

cleanup({_StorePid, _SupPid}) ->
    %% Don't kill registered processes - they may be shared across tests
    ok.

%% Test: Listener joins pg group on startup
listener_joins_pg_group_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     fun(_) ->
         %% Check that our listener is in the pg group
         Members = pg:get_members(?SCOPE, ?GROUP),
         ?_assert(length(Members) > 0)
     end}.

%% Test: Event emitted to pg triggers projection
pg_event_triggers_projection_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     fun(_) ->
         %% Create a unique torch ID for this test
         TorchId = <<"test-torch-", (integer_to_binary(erlang:system_time(microsecond)))/binary>>,

         %% Create and emit event via pg
         Event = #{
             torch_id => TorchId,
             name => <<"Integration Test Torch">>,
             brief => <<"Testing pg -> projection flow">>,
             initiated_at => erlang:system_time(millisecond),
             initiated_by => <<"test-runner">>
         },

         %% Send to pg group members (simulating what the emitter does)
         Message = {torch_initiated_v1, Event},
         lists:foreach(fun(Pid) -> Pid ! Message end, pg:get_members(?SCOPE, ?GROUP)),

         %% Give listener time to process
         timer:sleep(200),

         %% Query the database to verify projection worked
         {ok, Rows} = query_torches_store:query(
             "SELECT torch_id, name, brief FROM torches WHERE torch_id = ?1",
             [TorchId]
         ),

         [
             ?_assertEqual(1, length(Rows)),
             %% esqlite3 returns rows as lists, not tuples
             ?_assertMatch([[TorchId, <<"Integration Test Torch">>, <<"Testing pg -> projection flow">>]], Rows)
         ]
     end}.

%% Test: Full integration - emitter -> pg -> listener -> projection -> query
full_integration_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     fun(_) ->
         TorchId = <<"full-integ-", (integer_to_binary(erlang:system_time(microsecond)))/binary>>,

         Event = #{
             torch_id => TorchId,
             name => <<"Full Integration Torch">>,
             brief => <<"End to end test">>,
             initiated_at => erlang:system_time(millisecond),
             initiated_by => <<"integration-test">>
         },

         %% Use the actual emitter module
         ok = torch_initiated_v1_to_pg:emit(Event),

         %% Wait for async processing
         timer:sleep(200),

         %% Verify via list_torches query
         {ok, Torches} = list_torches:execute(#{limit => 100}),

         %% Find our torch
         MatchingTorches = [T || T <- Torches, maps:get(torch_id, T) =:= TorchId],

         [
             ?_assertEqual(1, length(MatchingTorches)),
             ?_assertEqual(<<"Full Integration Torch">>, maps:get(name, hd(MatchingTorches))),
             ?_assertEqual(<<"End to end test">>, maps:get(brief, hd(MatchingTorches))),
             ?_assertEqual(1, maps:get(status, hd(MatchingTorches)))
         ]
     end}.

%% Internal helpers

ensure_pg() ->
    case pg:start(?SCOPE) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.
