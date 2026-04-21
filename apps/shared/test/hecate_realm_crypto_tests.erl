-module(hecate_realm_crypto_tests).
-include_lib("eunit/include/eunit.hrl").

-define(TABLE, realm_shared_keys).
-define(REALM, <<"io.macula.test">>).

wrap_unwrap_roundtrip_test_() ->
    {setup, fun setup/0, fun teardown/1, fun(_) ->
        [
            {"round-trips plaintext through K_realm",
             fun() ->
                 Plaintext = <<"hello, K_realm wraps things">>,
                 {ok, Wrapped} = hecate_realm_crypto:wrap(?REALM, Plaintext),
                 ?assertNotEqual(Plaintext, Wrapped),
                 {ok, Got} = hecate_realm_crypto:unwrap(?REALM, Wrapped),
                 ?assertEqual(Plaintext, Got)
             end},

            {"current/1 returns version info without plaintext",
             fun() ->
                 {ok, Info} = hecate_realm_crypto:current(?REALM),
                 ?assertEqual(42, maps:get(version, Info)),
                 ?assertNot(maps:is_key(k_realm_encrypted, Info)),
                 ?assertNot(maps:is_key(plaintext, Info))
             end},

            {"has_key/1 true for seeded realm",
             fun() -> ?assert(hecate_realm_crypto:has_key(?REALM)) end},

            {"has_key/1 false for unknown realm",
             fun() -> ?assertNot(hecate_realm_crypto:has_key(<<"nope">>)) end},

            {"wrap against missing realm fails",
             fun() ->
                 ?assertMatch({error, {no_realm_key, _}},
                              hecate_realm_crypto:wrap(<<"nope">>, <<"x">>))
             end},

            {"tampered ciphertext fails",
             fun() ->
                 {ok, Wrapped} = hecate_realm_crypto:wrap(?REALM, <<"payload">>),
                 <<Head:32/binary, Tail/binary>> = Wrapped,
                 FlippedTail = crypto:exor(Tail, crypto:strong_rand_bytes(byte_size(Tail))),
                 ?assertMatch({error, _},
                              hecate_realm_crypto:unwrap(?REALM,
                                                         <<Head/binary, FlippedTail/binary>>))
             end}
        ]
    end}.

%% ===================================================================
%% setup / teardown — seed the ETS table directly (projection-free)
%% ===================================================================

setup() ->
    ensure_table(),
    %% Mint a fresh plaintext K_realm, seal it with hecate_crypto
    %% (same path as the PM takes), and put a row in the table.
    Plaintext = crypto:strong_rand_bytes(32),
    {ok, Sealed} = hecate_crypto:encrypt(Plaintext),
    Entry = #{
        realm             => ?REALM,
        k_realm_version   => 42,
        k_realm_encrypted => Sealed,
        received_at       => erlang:system_time(millisecond),
        membership_id     => <<"mem-test">>
    },
    ets:insert(?TABLE, {?REALM, Entry}),
    ok.

teardown(_) ->
    ets:delete(?TABLE, ?REALM),
    ok.

ensure_table() ->
    case ets:whereis(?TABLE) of
        undefined ->
            ?TABLE = ets:new(?TABLE, [set, public, named_table]),
            ok;
        _Tid ->
            ok
    end.
