-module(hecate_did_crypto_tests).
-include_lib("eunit/include/eunit.hrl").

roundtrip_test() ->
    {BobPub, BobPriv} = crypto:generate_key(ecdh, x25519),
    Plaintext = <<"hello, did-crypto">>,
    {ok, Sealed} = hecate_did_crypto:wrap_for_pubkey(BobPub, Plaintext),
    ?assertNotEqual(Plaintext, Sealed),
    %% envelope overhead: 32 eph_pub + 12 nonce + 16 tag
    ?assertEqual(byte_size(Plaintext) + 60, byte_size(Sealed)),
    {ok, Got} = hecate_did_crypto:unwrap_with_privkey(BobPriv, Sealed),
    ?assertEqual(Plaintext, Got).

wrong_recipient_fails_test() ->
    {BobPub, _BobPriv} = crypto:generate_key(ecdh, x25519),
    {_CarolPub, CarolPriv} = crypto:generate_key(ecdh, x25519),
    {ok, Sealed} = hecate_did_crypto:wrap_for_pubkey(BobPub, <<"secret">>),
    ?assertMatch({error, bad_ciphertext},
                 hecate_did_crypto:unwrap_with_privkey(CarolPriv, Sealed)).

tamper_ciphertext_fails_test() ->
    {BobPub, BobPriv} = crypto:generate_key(ecdh, x25519),
    {ok, Sealed} = hecate_did_crypto:wrap_for_pubkey(BobPub, <<"payload here">>),
    %% Flip a bit in the ciphertext tail
    <<Head:60/binary, Byte, Rest/binary>> = Sealed,
    Tampered = <<Head/binary, (Byte bxor 16#FF), Rest/binary>>,
    ?assertMatch({error, bad_ciphertext},
                 hecate_did_crypto:unwrap_with_privkey(BobPriv, Tampered)).

tamper_nonce_fails_test() ->
    {BobPub, BobPriv} = crypto:generate_key(ecdh, x25519),
    {ok, Sealed} = hecate_did_crypto:wrap_for_pubkey(BobPub, <<"payload">>),
    %% Nonce is at bytes 32..43
    <<Head:32/binary, _Nonce:12/binary, Rest/binary>> = Sealed,
    BadNonce = <<0:(12*8)>>,
    Tampered = <<Head/binary, BadNonce/binary, Rest/binary>>,
    ?assertMatch({error, bad_ciphertext},
                 hecate_did_crypto:unwrap_with_privkey(BobPriv, Tampered)).

tamper_ephpub_fails_test() ->
    {BobPub, BobPriv} = crypto:generate_key(ecdh, x25519),
    {ok, Sealed} = hecate_did_crypto:wrap_for_pubkey(BobPub, <<"payload">>),
    %% Replace the ephemeral pubkey → shared secret changes → MAC fails
    {RandPub, _} = crypto:generate_key(ecdh, x25519),
    <<_OldEph:32/binary, Rest/binary>> = Sealed,
    Tampered = <<RandPub/binary, Rest/binary>>,
    ?assertMatch({error, bad_ciphertext},
                 hecate_did_crypto:unwrap_with_privkey(BobPriv, Tampered)).

bad_pubkey_size_rejected_test() ->
    ?assertEqual({error, bad_pubkey},
                 hecate_did_crypto:wrap_for_pubkey(<<0:32>>, <<"x">>)),
    ?assertEqual({error, bad_pubkey},
                 hecate_did_crypto:wrap_for_pubkey(<<0:(64*8)>>, <<"x">>)).

bad_sealed_rejected_test() ->
    {_Pub, Priv} = crypto:generate_key(ecdh, x25519),
    ?assertEqual({error, bad_sealed},
                 hecate_did_crypto:unwrap_with_privkey(Priv, <<"too short">>)).

large_payload_test() ->
    {BobPub, BobPriv} = crypto:generate_key(ecdh, x25519),
    Plaintext = crypto:strong_rand_bytes(4096),
    {ok, Sealed} = hecate_did_crypto:wrap_for_pubkey(BobPub, Plaintext),
    {ok, Got} = hecate_did_crypto:unwrap_with_privkey(BobPriv, Sealed),
    ?assertEqual(Plaintext, Got).

each_wrap_uses_fresh_ephemeral_test() ->
    %% Two wraps of the same payload to the same recipient produce
    %% different ciphertexts (fresh ephemeral + fresh nonce).
    {BobPub, _} = crypto:generate_key(ecdh, x25519),
    {ok, S1} = hecate_did_crypto:wrap_for_pubkey(BobPub, <<"same">>),
    {ok, S2} = hecate_did_crypto:wrap_for_pubkey(BobPub, <<"same">>),
    ?assertNotEqual(S1, S2).
