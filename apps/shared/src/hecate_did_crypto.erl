%%%-------------------------------------------------------------------
%%% @doc DID-scope encryption (identity-scoped CEK wrapping).
%%%
%%% Implements X25519 ECIES (ephemeral-static) for anyone-to-recipient
%%% envelope encryption. Alice wraps a CEK for Bob using Bob's X25519
%%% public key + a fresh ephemeral keypair; Bob unwraps using his own
%%% X25519 private key. Standard libsodium-style sealed-box, hand-rolled
%%% on OTP `crypto`.
%%%
%%% == Flow ==
%%%
%%%   Alice:
%%%     {EphPub, EphPriv} = crypto:generate_key(ecdh, x25519)
%%%     Shared = crypto:compute_key(ecdh, BobPub, EphPriv, x25519)
%%%     WrapKey = HKDF(sha256, Shared)
%%%     {CT, Tag} = AES-256-GCM(WrapKey, Nonce, Plaintext)
%%%     Output: <<EphPub:32, Nonce:12, Tag:16, CT/binary>>
%%%
%%%   Bob:
%%%     <<EphPub:32, Nonce:12, Tag:16, CT/binary>> = Sealed
%%%     Shared = crypto:compute_key(ecdh, EphPub, BobPriv, x25519)
%%%     WrapKey = HKDF(sha256, Shared)
%%%     Plaintext = AES-256-GCM-decrypt(WrapKey, Nonce, CT, Tag)
%%%
%%% == Properties ==
%%%
%%%   - Confidentiality: only the holder of BobPriv can unwrap.
%%%   - Integrity: AES-GCM tag rejects tampering on nonce/ciphertext/tag.
%%%   - Ephemeral pubkey in the envelope prevents key-reuse.
%%%   - No forward secrecy (static recipient key) — acceptable for
%%%     at-rest licenses; forward secrecy is Phase D non-goal.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_did_crypto).

-export([wrap_for_pubkey/2, unwrap_with_privkey/2]).

-define(NONCE_SIZE, 12).
-define(TAG_SIZE, 16).
-define(EPH_PUB_SIZE, 32).
-define(SHARED_KEY_SIZE, 32).

-type pubkey()  :: <<_:256>>.
-type privkey() :: <<_:256>>.
-type sealed()  :: binary().

-spec wrap_for_pubkey(pubkey(), binary()) -> {ok, sealed()} | {error, term()}.
wrap_for_pubkey(RecipientPub, Plaintext)
  when is_binary(RecipientPub), byte_size(RecipientPub) == ?EPH_PUB_SIZE,
       is_binary(Plaintext) ->
    {EphPub, EphPriv} = crypto:generate_key(ecdh, x25519),
    SharedSecret = crypto:compute_key(ecdh, RecipientPub, EphPriv, x25519),
    WrapKey = derive_wrap_key(SharedSecret),
    Nonce = crypto:strong_rand_bytes(?NONCE_SIZE),
    {CipherText, Tag} = crypto:crypto_one_time_aead(
        aes_256_gcm, WrapKey, Nonce, Plaintext, <<>>, ?TAG_SIZE, true),
    {ok, <<EphPub:?EPH_PUB_SIZE/binary,
           Nonce:?NONCE_SIZE/binary,
           Tag:?TAG_SIZE/binary,
           CipherText/binary>>};
wrap_for_pubkey(_BadPub, _Plaintext) ->
    {error, bad_pubkey}.

-spec unwrap_with_privkey(privkey(), sealed()) -> {ok, binary()} | {error, term()}.
unwrap_with_privkey(RecipientPriv,
                    <<EphPub:?EPH_PUB_SIZE/binary,
                      Nonce:?NONCE_SIZE/binary,
                      Tag:?TAG_SIZE/binary,
                      CipherText/binary>>)
  when is_binary(RecipientPriv), byte_size(RecipientPriv) == ?EPH_PUB_SIZE ->
    SharedSecret = crypto:compute_key(ecdh, EphPub, RecipientPriv, x25519),
    WrapKey = derive_wrap_key(SharedSecret),
    decode(crypto:crypto_one_time_aead(
        aes_256_gcm, WrapKey, Nonce, CipherText, <<>>, Tag, false));
unwrap_with_privkey(_BadPriv, _Bad) ->
    {error, bad_sealed}.

%%%===================================================================
%%% Internal
%%%===================================================================

derive_wrap_key(SharedSecret) ->
    %% HKDF with SHA-256, no salt, domain-separation label
    Info = <<"hecate-did-crypto-v1">>,
    Prk = crypto:mac(hmac, sha256, <<>>, SharedSecret),
    <<Okm:?SHARED_KEY_SIZE/binary, _/binary>> =
        crypto:mac(hmac, sha256, Prk, <<Info/binary, 1>>),
    Okm.

decode(Plaintext) when is_binary(Plaintext) -> {ok, Plaintext};
decode(error) -> {error, bad_ciphertext}.
