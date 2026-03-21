%%%-------------------------------------------------------------------
%%% @doc Credential encryption for Hecate.
%%%
%%% Encrypts sensitive data (OAuth tokens, certs, API keys) using
%%% AES-256-GCM with a key derived from the Erlang distribution cookie.
%%%
%%% The cookie is the cluster trust boundary — any node that can join
%%% the cluster can decrypt. No node outside the cluster can.
%%%
%%% Usage:
%%%   {ok, Encrypted} = hecate_crypto:encrypt(<<"my-secret-token">>).
%%%   {ok, Decrypted} = hecate_crypto:decrypt(Encrypted).
%%%
%%% The encrypted binary includes the IV and GCM auth tag, so it is
%%% self-contained and safe to store in ReckonDB event payloads.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_crypto).

-export([
    encrypt/1,
    decrypt/1,
    encrypt_map/1,
    decrypt_map/1
]).

%% AES-256-GCM parameters
-define(CIPHER, aes_256_gcm).
-define(IV_BYTES, 12).
-define(TAG_BYTES, 16).

%%%===================================================================
%%% API
%%%===================================================================

%% @doc Encrypt a binary using AES-256-GCM.
%% Returns {ok, EncryptedBinary} where the binary contains IV + Tag + CipherText.
-spec encrypt(binary()) -> {ok, binary()} | {error, term()}.
encrypt(Plaintext) when is_binary(Plaintext) ->
    Key = derive_key(),
    IV = crypto:strong_rand_bytes(?IV_BYTES),
    {CipherText, Tag} = crypto:crypto_one_time_aead(
        ?CIPHER, Key, IV, Plaintext, <<>>, ?TAG_BYTES, true
    ),
    %% Pack as: IV (12) + Tag (16) + CipherText (variable)
    {ok, <<IV:?IV_BYTES/binary, Tag:?TAG_BYTES/binary, CipherText/binary>>};
encrypt(_) ->
    {error, not_binary}.

%% @doc Decrypt a binary previously encrypted with encrypt/1.
-spec decrypt(binary()) -> {ok, binary()} | {error, term()}.
decrypt(<<IV:?IV_BYTES/binary, Tag:?TAG_BYTES/binary, CipherText/binary>>) ->
    Key = derive_key(),
    case crypto:crypto_one_time_aead(
        ?CIPHER, Key, IV, CipherText, <<>>, Tag, false
    ) of
        error -> {error, decryption_failed};
        Plaintext -> {ok, Plaintext}
    end;
decrypt(_) ->
    {error, invalid_encrypted_data}.

%% @doc Encrypt all values in a map, leaving keys unchanged.
%% Values must be binaries. Non-binary values are left as-is.
-spec encrypt_map(map()) -> {ok, map()} | {error, term()}.
encrypt_map(Map) when is_map(Map) ->
    encrypt_map_entries(maps:to_list(Map), #{}).

%% @doc Decrypt all values in a map previously encrypted with encrypt_map/1.
-spec decrypt_map(map()) -> {ok, map()} | {error, term()}.
decrypt_map(Map) when is_map(Map) ->
    decrypt_map_entries(maps:to_list(Map), #{}).

%%%===================================================================
%%% Internal
%%%===================================================================

%% @private Derive AES-256 key from Erlang cookie via SHA-256.
-spec derive_key() -> binary().
derive_key() ->
    Cookie = erlang:get_cookie(),
    crypto:hash(sha256, atom_to_binary(Cookie, utf8)).

%% @private Encrypt map entries one by one.
encrypt_map_entries([], Acc) ->
    {ok, Acc};
encrypt_map_entries([{Key, Value} | Rest], Acc) when is_binary(Value) ->
    case encrypt(Value) of
        {ok, Encrypted} ->
            encrypt_map_entries(Rest, Acc#{Key => Encrypted});
        {error, _} = Err ->
            Err
    end;
encrypt_map_entries([{Key, Value} | Rest], Acc) ->
    encrypt_map_entries(Rest, Acc#{Key => Value}).

%% @private Decrypt map entries one by one.
decrypt_map_entries([], Acc) ->
    {ok, Acc};
decrypt_map_entries([{Key, Value} | Rest], Acc) when is_binary(Value), byte_size(Value) > 28 ->
    %% Only attempt decryption on binaries large enough to contain IV + Tag
    case decrypt(Value) of
        {ok, Decrypted} ->
            decrypt_map_entries(Rest, Acc#{Key => Decrypted});
        {error, _} ->
            %% Not encrypted or wrong key — pass through
            decrypt_map_entries(Rest, Acc#{Key => Value})
    end;
decrypt_map_entries([{Key, Value} | Rest], Acc) ->
    decrypt_map_entries(Rest, Acc#{Key => Value}).
