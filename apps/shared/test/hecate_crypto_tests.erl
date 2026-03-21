-module(hecate_crypto_tests).
-include_lib("eunit/include/eunit.hrl").

encrypt_decrypt_roundtrip_test() ->
    Plaintext = <<"my-secret-refresh-token-abc123">>,
    {ok, Encrypted} = hecate_crypto:encrypt(Plaintext),
    ?assertNotEqual(Plaintext, Encrypted),
    {ok, Decrypted} = hecate_crypto:decrypt(Encrypted),
    ?assertEqual(Plaintext, Decrypted).

encrypt_produces_different_ciphertext_each_time_test() ->
    Plaintext = <<"same-input">>,
    {ok, Enc1} = hecate_crypto:encrypt(Plaintext),
    {ok, Enc2} = hecate_crypto:encrypt(Plaintext),
    %% Random IV means different ciphertext each time
    ?assertNotEqual(Enc1, Enc2),
    %% Both decrypt to the same value
    {ok, Dec1} = hecate_crypto:decrypt(Enc1),
    {ok, Dec2} = hecate_crypto:decrypt(Enc2),
    ?assertEqual(Dec1, Dec2).

decrypt_invalid_data_test() ->
    ?assertEqual({error, invalid_encrypted_data}, hecate_crypto:decrypt(<<"too-short">>)).

decrypt_tampered_data_test() ->
    {ok, Encrypted} = hecate_crypto:encrypt(<<"secret">>),
    %% Flip a byte in the ciphertext portion (after IV + Tag = 28 bytes)
    <<Head:29/binary, Byte:8, Tail/binary>> = Encrypted,
    Tampered = <<Head/binary, (Byte bxor 255):8, Tail/binary>>,
    ?assertEqual({error, decryption_failed}, hecate_crypto:decrypt(Tampered)).

encrypt_empty_binary_test() ->
    {ok, Encrypted} = hecate_crypto:encrypt(<<>>),
    {ok, Decrypted} = hecate_crypto:decrypt(Encrypted),
    ?assertEqual(<<>>, Decrypted).

encrypt_large_binary_test() ->
    Large = crypto:strong_rand_bytes(65536),
    {ok, Encrypted} = hecate_crypto:encrypt(Large),
    {ok, Decrypted} = hecate_crypto:decrypt(Encrypted),
    ?assertEqual(Large, Decrypted).

encrypt_map_roundtrip_test() ->
    Map = #{
        refresh_token => <<"tok-abc123">>,
        cert_pem => <<"-----BEGIN CERTIFICATE-----\nMIIB...">>,
        org_identity => <<"io.macula.rgfaber">>
    },
    {ok, Encrypted} = hecate_crypto:encrypt_map(Map),
    %% All values should be different from originals
    ?assertNotEqual(maps:get(refresh_token, Map), maps:get(refresh_token, Encrypted)),
    %% Roundtrip works
    {ok, Decrypted} = hecate_crypto:decrypt_map(Encrypted),
    ?assertEqual(Map, Decrypted).

encrypt_map_preserves_non_binary_values_test() ->
    Map = #{
        secret => <<"encrypt-me">>,
        count => 42,
        flag => true
    },
    {ok, Encrypted} = hecate_crypto:encrypt_map(Map),
    ?assertEqual(42, maps:get(count, Encrypted)),
    ?assertEqual(true, maps:get(flag, Encrypted)),
    ?assertNotEqual(<<"encrypt-me">>, maps:get(secret, Encrypted)).

encrypt_not_binary_test() ->
    ?assertEqual({error, not_binary}, hecate_crypto:encrypt(not_a_binary)).
