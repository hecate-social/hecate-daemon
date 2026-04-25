-module(licenses_rewrapped_batch_emitter_tests).
-include_lib("eunit/include/eunit.hrl").

-define(PUB_TAB, licenses_rewrapped_batch_emitter_tests_pubs).

setup() ->
    application:set_env(hecate, realm, <<"io.macula">>),
    ensure_pub_table(),
    ets:delete_all_objects(?PUB_TAB),
    KeyPair = macula_identity:generate(),
    meck:new(hecate_mesh, [passthrough, non_strict]),
    meck:expect(hecate_mesh, put_record,
                fun(Record) ->
                    ets:insert(?PUB_TAB,
                               {erlang:unique_integer([monotonic]),
                                Record}),
                    ok
                end),
    meck:new(hecate_identity, [passthrough, non_strict]),
    meck:expect(hecate_identity, signing_keypair,
                fun() -> {ok, KeyPair} end),
    {ok, Pid} = licenses_rewrapped_batch_emitter:start_link(),
    Pid.

cleanup(Pid) ->
    gen_server:stop(Pid),
    meck:unload(hecate_identity),
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
      fun coalesces_same_batch_id/1,
      fun publishes_new_version/1,
      fun drops_missing_realm/1,
      fun drops_missing_new_version/1]}.

forces_flush_on_demand(_Pid) ->
    fun() ->
        ok = licenses_rewrapped_batch_emitter:buffer(evt(<<"b1">>, <<"lic-1">>, 2)),
        ok = licenses_rewrapped_batch_emitter:buffer(evt(<<"b1">>, <<"lic-2">>, 2)),
        ?assertEqual(1, licenses_rewrapped_batch_emitter:pending()),
        ok = licenses_rewrapped_batch_emitter:flush(<<"b1">>),
        Record = wait_for_publish(2000),
        Payload = macula_record:payload(Record),
        ?assertEqual(<<"b1">>, maps:get({text, <<"batch_id">>}, Payload)),
        ?assertEqual(2, length(maps:get({text, <<"entries">>}, Payload)))
    end.

coalesces_same_batch_id(_Pid) ->
    fun() ->
        BatchId = <<"rotation-x">>,
        [ok = licenses_rewrapped_batch_emitter:buffer(evt(BatchId, lic_id(I), 3))
         || I <- lists:seq(1, 4)],
        ok = licenses_rewrapped_batch_emitter:flush(BatchId),
        Record = wait_for_publish(2000),
        Payload = macula_record:payload(Record),
        ?assertEqual(4, length(maps:get({text, <<"entries">>}, Payload))),
        ?assertEqual(3, maps:get({text, <<"new_k_realm_version">>}, Payload))
    end.

publishes_new_version(_Pid) ->
    fun() ->
        ok = licenses_rewrapped_batch_emitter:buffer(evt(<<"bv">>, <<"lic-v">>, 7)),
        ok = licenses_rewrapped_batch_emitter:flush(<<"bv">>),
        Record = wait_for_publish(2000),
        Payload = macula_record:payload(Record),
        ?assertEqual(7, maps:get({text, <<"new_k_realm_version">>}, Payload)),
        [Entry] = maps:get({text, <<"entries">>}, Payload),
        %% wrapped CEK is base64-encoded on the wire
        ?assertEqual(<<0, 1, 2, 3>>,
                     base64:decode(maps:get({text, <<"new_wrapped_cek">>}, Entry)))
    end.

drops_missing_realm(_Pid) ->
    fun() ->
        Bad = (evt(<<"bbad">>, <<"lic-bad">>, 2))#{realm => undefined},
        ok = licenses_rewrapped_batch_emitter:buffer(Bad),
        ok = licenses_rewrapped_batch_emitter:flush(<<"bbad">>),
        timer:sleep(100),
        ?assertEqual(0, ets:info(?PUB_TAB, size))
    end.

drops_missing_new_version(_Pid) ->
    fun() ->
        Bad = (evt(<<"bnov">>, <<"lic-nov">>, 2))#{new_k_realm_version => undefined},
        ok = licenses_rewrapped_batch_emitter:buffer(Bad),
        ok = licenses_rewrapped_batch_emitter:flush(<<"bnov">>),
        timer:sleep(100),
        ?assertEqual(0, ets:info(?PUB_TAB, size))
    end.

%% --- helpers ---

lic_id(I) -> list_to_binary("lic-" ++ integer_to_list(I)).

evt(BatchId, LicenseId, NewVersion) ->
    #{license_id          => LicenseId,
      grantee             => <<"mri:realm:io.macula">>,
      realm               => <<"io.macula">>,
      issuer_did          => <<"mri:agent:io.macula/alice/host00">>,
      new_wrapped_cek     => <<0, 1, 2, 3>>,
      new_k_realm_version => NewVersion,
      batch_id            => BatchId,
      rewrapped_at        => 9000}.

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
    [{Key, Record}] = ets:lookup(?PUB_TAB, Key),
    Record.
