%%% @doc Facade for realm-scoped symmetric crypto (`K_realm`).
%%%
%%% `K_realm` is the realm-wide shared key minted by the realm server
%%% and delivered to joining daemons. Each daemon stores the key
%%% sealed at rest via `hecate_crypto:encrypt/1` (Erlang-cookie-derived
%%% AES-256-GCM wrap). This module is the single place where plaintext
%%% `K_realm` bytes exist in-memory on the daemon — callers get
%%% ciphertext for wrap-of-CEK operations via `wrap/2` / `unwrap/2`
%%% and never see the plaintext directly.
%%%
%%% The plaintext briefly materialises inside this module for
%%% AES-256-GCM operations and is not returned to callers.
%%%
%%% Phase C scope: fetch + store + wrap/unwrap. Rotation-on-revoke,
%%% license-rewrap process managers, and boot-time catch-up are
%%% future work (see PLAN_BRIEFCASE_PRESENCE_PRIVACY.md Phase D).
%%% @end
-module(hecate_realm_crypto).

-export([current/1, has_key/1, wrap/2, unwrap/2]).

-define(NONCE_SIZE, 12).
-define(TAG_SIZE, 16).

%% ETS table owned by project_realm_memberships_store. Accessed by
%% name to avoid a code dep from `shared` up into the PRJ layer.
-define(SHARED_KEYS_TABLE, realm_shared_keys).

-type wrap_result() :: {ok, binary()} | {error, term()}.
-type key_info()    :: #{version := pos_integer(),
                         received_at := integer(),
                         membership_id => binary()}.

%%====================================================================
%% API
%%====================================================================

%% @doc Current sealed-version info for a realm, or not_found.
%% Does NOT return plaintext bytes — use wrap/2 or unwrap/2 to act
%% on payloads with the key.
-spec current(binary()) -> {ok, key_info()} | {error, not_found}.
current(Realm) when is_binary(Realm) ->
    case lookup(Realm) of
        {ok, #{k_realm_version := V, received_at := At} = Entry} ->
            Info = maps:with([membership_id], Entry),
            {ok, Info#{version => V, received_at => At}};
        {error, _} = Err ->
            Err
    end.

-spec has_key(binary()) -> boolean().
has_key(Realm) when is_binary(Realm) ->
    case current(Realm) of
        {ok, _}         -> true;
        {error, _}      -> false
    end.

%% @doc AES-256-GCM encrypt `Plaintext` with the realm's `K_realm`.
%% Output format: `<<Nonce:12, Tag:16, Ciphertext/binary>>`.
-spec wrap(binary(), binary()) -> wrap_result().
wrap(Realm, Plaintext) when is_binary(Realm), is_binary(Plaintext) ->
    with_key(Realm, fun(KRealm) -> do_wrap(KRealm, Plaintext) end).

%% @doc AES-256-GCM decrypt a `wrap/2` output.
-spec unwrap(binary(), binary()) -> wrap_result().
unwrap(Realm, Sealed) when is_binary(Realm), is_binary(Sealed) ->
    with_key(Realm, fun(KRealm) -> do_unwrap(KRealm, Sealed) end).

%%====================================================================
%% Internal
%%====================================================================

%% Materialise plaintext K_realm inside a restricted scope and hand it
%% to Fun. The plaintext is not returned — it lives only within Fun.
with_key(Realm, Fun) ->
    case lookup(Realm) of
        {ok, #{k_realm_encrypted := Sealed}} ->
            unseal_and_apply(Sealed, Fun);
        {error, not_found} ->
            {error, {no_realm_key, Realm}}
    end.

lookup(Realm) ->
    %% The table is created by project_realm_memberships_store before
    %% any domain app boots. If it's missing we treat it as not_found
    %% rather than crashing, so callers see a clean {error, _}.
    case ets:whereis(?SHARED_KEYS_TABLE) of
        undefined -> {error, not_found};
        _Tid      -> lookup_row(Realm)
    end.

lookup_row(Realm) ->
    case ets:lookup(?SHARED_KEYS_TABLE, Realm) of
        [{_, Entry}] -> {ok, Entry};
        []           -> {error, not_found}
    end.

unseal_and_apply(Sealed, Fun) ->
    case hecate_crypto:decrypt(Sealed) of
        {ok, KRealm} when byte_size(KRealm) == 32 ->
            Fun(KRealm);
        {ok, _BadSize} ->
            {error, malformed_realm_key};
        {error, _} = Err ->
            Err
    end.

do_wrap(KRealm, Plaintext) ->
    Nonce = crypto:strong_rand_bytes(?NONCE_SIZE),
    {Cipher, Tag} = crypto:crypto_one_time_aead(
        aes_256_gcm, KRealm, Nonce, Plaintext, <<>>, true),
    {ok, <<Nonce:?NONCE_SIZE/binary, Tag:?TAG_SIZE/binary, Cipher/binary>>}.

do_unwrap(KRealm, <<Nonce:?NONCE_SIZE/binary, Tag:?TAG_SIZE/binary, Cipher/binary>>) ->
    decode(crypto:crypto_one_time_aead(
        aes_256_gcm, KRealm, Nonce, Cipher, <<>>, Tag, false));
do_unwrap(_KRealm, _Bad) ->
    {error, bad_ciphertext}.

decode(Plaintext) when is_binary(Plaintext) -> {ok, Plaintext};
decode(error) -> {error, bad_ciphertext}.
