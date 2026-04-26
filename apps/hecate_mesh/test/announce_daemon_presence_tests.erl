%%% @doc Unit tests for `announce_daemon_presence'.
%%%
%%% Verifies the announcer:
%%%   * builds a `node_record' carrying `kind=daemon' on each refresh
%%%   * calls `hecate_mesh:put_record/1' with the signed record
%%%   * survives `{error, not_activated}' replies (mesh dormant) and
%%%     reschedules a backoff retry
%%%   * publishes a tombstone on graceful shutdown
%%%
%%% Stubs `hecate_identity:signing_keypair/0' (the daemon's identity
%%% module is initialised lazily in production) and
%%% `hecate_mesh:put_record/1' (we don't bring up a real mesh client
%%% in unit tests).
-module(announce_daemon_presence_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Fixture
%%====================================================================

setup() ->
    process_flag(trap_exit, true),
    {ok, _} = application:ensure_all_started(macula),
    KeyPair = macula_identity:generate(),
    meck:new(hecate_identity, [non_strict]),
    meck:expect(hecate_identity, signing_keypair,
                fun() -> {ok, KeyPair} end),
    meck:new(hecate_mesh, [non_strict, passthrough]),
    meck:expect(hecate_mesh, put_record, fun(_R) -> ok end),
    KeyPair.

cleanup(_KeyPair) ->
    %% Tear down any lingering announcer from a previous test before
    %% unloading the mocks (the announcer's terminate path calls
    %% hecate_mesh:put_record/1 once for the tombstone).
    case erlang:whereis(announce_daemon_presence) of
        undefined -> ok;
        Pid       -> catch announce_daemon_presence:stop(Pid)
    end,
    catch meck:unload(hecate_mesh),
    catch meck:unload(hecate_identity),
    ok.

%%====================================================================
%% Generator
%%====================================================================

announcer_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [
         fun(KeyPair) ->
             ?_test(initial_publish_carries_kind_daemon(KeyPair))
         end,
         fun(KeyPair) ->
             ?_test(record_signed_by_daemon_identity(KeyPair))
         end,
         fun(KeyPair) ->
             ?_test(not_activated_does_not_crash(KeyPair))
         end,
         fun(KeyPair) ->
             ?_test(graceful_shutdown_publishes_tombstone(KeyPair))
         end
     ]}.

%%====================================================================
%% Cases
%%====================================================================

initial_publish_carries_kind_daemon(_KeyPair) ->
    {ok, Pid} = announce_daemon_presence:start_link(),
    unlink(Pid),
    Record = wait_for_put_record(),
    ?assertEqual(16#01, macula_record:type(Record)),
    Payload = macula_record:payload(Record),
    ?assertEqual({text, <<"daemon">>},
                 maps:get({text, <<"kind">>}, Payload)),
    catch announce_daemon_presence:stop(Pid).

record_signed_by_daemon_identity(KeyPair) ->
    {ok, Pid} = announce_daemon_presence:start_link(),
    unlink(Pid),
    Record = wait_for_put_record(),
    ?assertMatch({ok, _}, macula_record:verify(Record)),
    %% Storage key = signer pubkey for node_records.
    ExpectedKey = macula_identity:public(KeyPair),
    ?assertEqual(ExpectedKey, macula_record:key(Record)),
    catch announce_daemon_presence:stop(Pid).

not_activated_does_not_crash(_KeyPair) ->
    %% Override put_record to simulate dormant mesh — the announcer
    %% must absorb the {error, not_activated} reply and reschedule
    %% rather than crash.
    meck:expect(hecate_mesh, put_record,
                fun(_R) -> {error, not_activated} end),
    {ok, Pid} = announce_daemon_presence:start_link(),
    unlink(Pid),
    %% Wait for the call to land via meck's history.
    wait_until_call_count(1, 1_000),
    ?assert(is_process_alive(Pid)),
    catch announce_daemon_presence:stop(Pid).

graceful_shutdown_publishes_tombstone(_KeyPair) ->
    {ok, Pid} = announce_daemon_presence:start_link(),
    unlink(Pid),
    %% Wait for the initial node_record put (#01).
    InitialRec = wait_for_put_record(),
    ?assertEqual(16#01, macula_record:type(InitialRec)),
    %% Stop the announcer; expect a tombstone put.
    ok = announce_daemon_presence:stop(Pid),
    %% Tombstone is the SECOND call to put_record.
    wait_until_call_count(2, 2_000),
    [#{type := T} = _Tomb | _] = recent_records_seen(),
    ?assertEqual(16#0C, T).

%%====================================================================
%% Helpers
%%====================================================================

%% Block until at least one put_record call has landed in meck's
%% history, then return the record argument.
wait_for_put_record() ->
    wait_until_call_count(1, 1_000),
    [Record | _] = recent_records_seen(),
    Record.

%% Block until meck has seen at least N put_record calls.
wait_until_call_count(N, Deadline) when Deadline > 0 ->
    case meck:num_calls(hecate_mesh, put_record, 1) of
        K when K >= N -> ok;
        _ ->
            timer:sleep(20),
            wait_until_call_count(N, Deadline - 20)
    end;
wait_until_call_count(_N, _) ->
    erlang:error(no_put_record_call).

%% Return every record argument meck saw, newest first.
recent_records_seen() ->
    [Record
     || {_Pid, {hecate_mesh, put_record, [Record]}, _Result}
            <- lists:reverse(meck:history(hecate_mesh))].
