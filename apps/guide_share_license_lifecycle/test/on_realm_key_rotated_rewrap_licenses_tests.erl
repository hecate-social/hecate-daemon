-module(on_realm_key_rotated_rewrap_licenses_tests).
-include_lib("eunit/include/eunit.hrl").

%% Tests the PM's handle_rotation logic without touching ReckonDB or
%% the event handler framework. We inject dispatch_fn + crypto seams
%% via the handler's init config so we can capture dispatches.

pm_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun skips_first_version/1,
      fun skips_on_empty_entries/1,
      fun dispatches_rewrap_for_each_entry/1,
      fun uses_shared_batch_id/1,
      fun logs_and_skips_on_unseal_error/1]}.

setup() ->
    ets:new(captured, [named_table, public, ordered_set]),
    ok.

cleanup(_) ->
    ets:delete(captured),
    ok.

skips_first_version(_) ->
    fun() ->
        Config = test_config(fun(_R, _V) -> {ok, []} end),
        Event = key_stored_event(<<"io.macula">>, 1),
        {ok, _} = on_realm_key_rotated_rewrap_licenses:handle_event(
                    <<"realm_shared_key_stored_v1">>, Event, #{},
                    init_config(Config)),
        ?assertEqual(0, ets:info(captured, size))
    end.

skips_on_empty_entries(_) ->
    fun() ->
        Config = test_config(fun(_R, _V) -> {ok, []} end),
        Event = key_stored_event(<<"io.macula">>, 3),
        {ok, _} = on_realm_key_rotated_rewrap_licenses:handle_event(
                    <<"realm_shared_key_stored_v1">>, Event, #{},
                    init_config(Config)),
        ?assertEqual(0, ets:info(captured, size))
    end.

dispatches_rewrap_for_each_entry(_) ->
    fun() ->
        Entries = [entry(<<"lic-1">>), entry(<<"lic-2">>), entry(<<"lic-3">>)],
        Config = test_config(fun(<<"io.macula">>, 2) -> {ok, Entries} end),
        Event = key_stored_event(<<"io.macula">>, 3),
        {ok, _} = on_realm_key_rotated_rewrap_licenses:handle_event(
                    <<"realm_shared_key_stored_v1">>, Event, #{},
                    init_config(Config)),
        ?assertEqual(3, ets:info(captured, size))
    end.

uses_shared_batch_id(_) ->
    fun() ->
        Entries = [entry(<<"lic-1">>), entry(<<"lic-2">>)],
        Config = test_config(fun(_, _) -> {ok, Entries} end),
        Event = key_stored_event(<<"io.macula">>, 4),
        {ok, _} = on_realm_key_rotated_rewrap_licenses:handle_event(
                    <<"realm_shared_key_stored_v1">>, Event, #{},
                    init_config(Config)),
        Dispatched = all_captured(),
        [First | _] = Dispatched,
        BatchId = maps:get(batch_id, First),
        ?assert(lists:all(fun(D) -> maps:get(batch_id, D) =:= BatchId end,
                          Dispatched)),
        ?assertEqual(2, length(Dispatched))
    end.

logs_and_skips_on_unseal_error(_) ->
    fun() ->
        Entries = [entry(<<"lic-fail">>)],
        Config0 = test_config(fun(_, _) -> {ok, Entries} end),
        %% override unseal to fail
        Config = Config0#{unseal_fn => fun(_) -> {error, bad} end},
        Event = key_stored_event(<<"io.macula">>, 2),
        {ok, _} = on_realm_key_rotated_rewrap_licenses:handle_event(
                    <<"realm_shared_key_stored_v1">>, Event, #{},
                    init_config(Config)),
        ?assertEqual(0, ets:info(captured, size))
    end.

%% --- helpers ---

init_config(Overrides) ->
    Default = on_realm_key_rotated_rewrap_licenses:default_config(),
    maps:merge(Default, Overrides).

test_config(ListFn) ->
    #{list_fn     => ListFn,
      unseal_fn   => fun(_Sealed) -> {ok, <<"plaintext-cek">>} end,
      rewrap_fn   => fun(_Sealed, <<"plaintext-cek">>) ->
                         {ok, <<"re-wrapped">>} end,
      dispatch_fn => fun(Cmd) ->
                         Map = rewrap_license_v1:to_map(Cmd),
                         ets:insert(captured,
                                    {erlang:unique_integer([monotonic]), Map}),
                         {ok, 1, []}
                     end,
      uuid_fn     => fun() -> <<"test-batch-id">> end}.

key_stored_event(Realm, NewVersion) ->
    #{data => #{
        event_type        => <<"realm_shared_key_stored_v1">>,
        membership_id     => <<"mem-1">>,
        realm             => Realm,
        k_realm_version   => NewVersion,
        k_realm_encrypted => <<"sealed-k-realm">>,
        received_at       => 1234
    }}.

entry(LicenseId) ->
    #{license_id        => LicenseId,
      realm             => <<"io.macula">>,
      k_realm_version   => 2,
      wrap_strategy     => realm_key_v1,
      wrapped_cek       => <<"old-wrap">>,
      origin_cek_sealed => <<"sealed-cek">>,
      issuer_did        => <<"mri:agent:io.macula/alice/host00">>,
      grantee           => <<"mri:realm:io.macula">>,
      issued_at         => 1000,
      rewrapped_at      => undefined}.

all_captured() ->
    [M || {_, M} <- ets:tab2list(captured)].
