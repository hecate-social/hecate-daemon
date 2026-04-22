-module(hecate_file_cek_tests).
-include_lib("eunit/include/eunit.hrl").

-define(TABLE, my_issued_files).

setup() ->
    case ets:info(?TABLE) of
        undefined -> ets:new(?TABLE, [public, named_table, set]);
        _         -> ets:delete_all_objects(?TABLE)
    end,
    ok.

cleanup(_) ->
    case ets:info(?TABLE) of
        undefined -> ok;
        _         -> ets:delete_all_objects(?TABLE)
    end,
    ok.

cek_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun sealed_lookup_hit/1,
      fun sealed_lookup_miss/1,
      fun unseal_roundtrip/1,
      fun unseal_rejects_bad_size/1]}.

sealed_lookup_hit(_) ->
    fun() ->
        Sealed = <<"sealed-bytes">>,
        ets:insert(?TABLE, {<<"file-1">>,
                            #{file_id => <<"file-1">>,
                              origin_cek_sealed => Sealed}}),
        ?assertEqual({ok, Sealed},
                     hecate_file_cek:sealed(<<"file-1">>))
    end.

sealed_lookup_miss(_) ->
    fun() ->
        ?assertEqual({error, not_found},
                     hecate_file_cek:sealed(<<"unknown">>))
    end.

unseal_roundtrip(_) ->
    fun() ->
        Cek = crypto:strong_rand_bytes(32),
        {ok, Sealed} = hecate_crypto:encrypt(Cek),
        ?assertEqual({ok, Cek}, hecate_file_cek:unseal(Sealed))
    end.

unseal_rejects_bad_size(_) ->
    fun() ->
        %% A 16-byte sealed value decrypts to 16 bytes — not 32.
        {ok, Sealed} = hecate_crypto:encrypt(<<"not a 32-byte key">>),
        ?assertEqual({error, bad_cek_size},
                     hecate_file_cek:unseal(Sealed))
    end.
