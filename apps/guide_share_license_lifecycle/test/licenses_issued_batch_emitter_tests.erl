-module(licenses_issued_batch_emitter_tests).
-include_lib("eunit/include/eunit.hrl").

%% Fixture: start the emitter + stub out hecate_mesh:publish via meck.
%% The stub writes into a named ETS table; tests poll it. Using ETS
%% (not the test process' mailbox) works regardless of which process
%% the meck stub runs in.

-define(PUB_TAB, licenses_issued_batch_emitter_tests_pubs).

setup() ->
    application:set_env(hecate, realm, <<"io.macula">>),
    ensure_pub_table(),
    ets:delete_all_objects(?PUB_TAB),
    meck:new(hecate_mesh, [passthrough, non_strict]),
    meck:expect(hecate_mesh, publish,
                fun(Topic, Fact) ->
                    ets:insert(?PUB_TAB,
                               {erlang:unique_integer([monotonic]),
                                Topic, Fact}),
                    ok
                end),
    {ok, Pid} = licenses_issued_batch_emitter:start_link(),
    Pid.

cleanup(Pid) ->
    gen_server:stop(Pid),
    meck:unload(hecate_mesh),
    ets:delete_all_objects(?PUB_TAB).

ensure_pub_table() ->
    case ets:info(?PUB_TAB) of
        undefined -> ets:new(?PUB_TAB, [named_table, public, ordered_set]);
        _         -> ok
    end.

emitter_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun forces_flush_on_demand/1,
      fun flushes_on_quiescence/1,
      fun batches_same_batch_id/1,
      fun skips_batch_missing_realm/1]}.

forces_flush_on_demand(_Pid) ->
    fun() ->
        ok = licenses_issued_batch_emitter:buffer(evt(<<"b1">>, <<"lic-1">>)),
        ok = licenses_issued_batch_emitter:buffer(evt(<<"b1">>, <<"lic-2">>)),
        ?assertEqual(1, licenses_issued_batch_emitter:pending()),
        ok = licenses_issued_batch_emitter:flush(<<"b1">>),
        Fact = wait_for_publish(2000),
        ?assertEqual(<<"b1">>, maps:get(batch_id, Fact)),
        ?assertEqual(2, length(maps:get(entries, Fact)))
    end.

flushes_on_quiescence(_Pid) ->
    fun() ->
        ok = licenses_issued_batch_emitter:buffer(evt(<<"bQ">>, <<"lic-q">>)),
        Fact = wait_for_publish(1500),
        ?assertEqual(<<"bQ">>, maps:get(batch_id, Fact))
    end.

batches_same_batch_id(_Pid) ->
    fun() ->
        BatchId = <<"bmulti">>,
        [ok = licenses_issued_batch_emitter:buffer(evt(BatchId, lic_id(I)))
         || I <- lists:seq(1, 5)],
        ok = licenses_issued_batch_emitter:flush(BatchId),
        Fact = wait_for_publish(2000),
        ?assertEqual(5, length(maps:get(entries, Fact)))
    end.

skips_batch_missing_realm(_Pid) ->
    fun() ->
        Bad = (evt(<<"bbad">>, <<"lic-bad">>))#{realm => undefined},
        ok = licenses_issued_batch_emitter:buffer(Bad),
        ok = licenses_issued_batch_emitter:flush(<<"bbad">>),
        timer:sleep(100),
        ?assertEqual(0, ets:info(?PUB_TAB, size))
    end.

%% --- helpers ---

lic_id(I) -> list_to_binary("lic-" ++ integer_to_list(I)).

evt(BatchId, LicenseId) ->
    #{license_id      => LicenseId,
      file_id         => <<"file-f">>,
      grantee         => <<"mri:realm:io.macula">>,
      wrap_strategy   => realm_key_v1,
      wrapped_cek     => <<0, 1, 2, 3>>,
      k_realm_version => 1,
      issuer_did      => <<"mri:agent:io.macula/alice/host00">>,
      realm           => <<"io.macula">>,
      batch_id        => BatchId,
      issued_at       => 100,
      expires_at      => 999}.

wait_for_publish(TimeoutMs) ->
    Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
    wait_loop(Deadline).

wait_loop(Deadline) ->
    case ets:info(?PUB_TAB, size) of
        0 ->
            Remaining = Deadline - erlang:monotonic_time(millisecond),
            assert_not_expired(Remaining),
            timer:sleep(25),
            wait_loop(Deadline);
        _ ->
            first_fact()
    end.

assert_not_expired(R) when R > 0 -> ok;
assert_not_expired(_) -> erlang:error(timeout_waiting_for_publish).

first_fact() ->
    Key = ets:first(?PUB_TAB),
    [{Key, _Topic, Fact}] = ets:lookup(?PUB_TAB, Key),
    Fact.
