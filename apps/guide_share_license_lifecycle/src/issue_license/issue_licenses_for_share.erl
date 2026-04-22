%%% @doc Orchestrator: mint CEK + wrap per recipient + dispatch
%%% `issue_license_v1` per grantee when a file is shared.
%%%
%%% Called from `share_file_api` AFTER `share_file_v1` persists so the
%%% CEK minting happens once (and is NOT re-minted on event replay).
%%% Resolves DID-scope recipient pubkeys via a single mesh RPC call
%%% to `io.macula.realm.get_member_public_keys`.
%%%
%%% Returns `{ok, #{batch_id, license_ids}}` with the ids of the
%%% licenses dispatched, so the API handler can echo them to the
%%% client for auditability.
%%%
%%% Recipients can be:
%%%   - `realm` / `<<"realm">>` — single realm-scoped license.
%%%   - `[DID, ...]`          — one DID-scope license per DID.
%%%   - mixed: `[realm | DIDs]` — realm-scope + per-DID (caller's call).
%%% @end
-module(issue_licenses_for_share).

-export([dispatch_for/4]).

-define(PUBKEY_RPC, <<"io.macula.realm.get_member_public_keys">>).
-define(PUBKEY_RPC_TIMEOUT, 10000).

-type recipient() :: realm | binary().
-type result() :: {ok, #{batch_id := binary(),
                         license_ids := [binary()]}} | {error, term()}.

-spec dispatch_for(binary(), binary(), binary(), [recipient()]) -> result().
dispatch_for(FileId, Realm, IssuerDid, Recipients)
  when is_binary(FileId), is_binary(Realm),
       is_binary(IssuerDid), is_list(Recipients),
       Recipients =/= [] ->
    Cek      = crypto:strong_rand_bytes(32),
    case seal_origin(Cek) of
        {ok, OriginSealed} ->
            do_dispatch(FileId, Realm, IssuerDid, Recipients,
                        Cek, OriginSealed);
        {error, _} = Err ->
            Err
    end;
dispatch_for(_, _, _, []) ->
    {error, no_recipients};
dispatch_for(_, _, _, _) ->
    {error, bad_args}.

%%====================================================================
%% Internal
%%====================================================================

do_dispatch(FileId, Realm, IssuerDid, Recipients, Cek, OriginSealed) ->
    BatchId = gen_id(<<"batch-">>),
    Dids    = [D || D <- Recipients, is_binary(D)],
    case resolve_pubkeys(Realm, Dids) of
        {ok, DidKeys} ->
            Issued = lists:foldl(
                fun(R, Acc) ->
                    dispatch_one(R, Acc, FileId, Realm, IssuerDid, Cek,
                                 OriginSealed, BatchId, DidKeys)
                end, {ok, []}, Recipients),
            finish(BatchId, Issued);
        {error, _} = Err ->
            Err
    end.

dispatch_one(_R, {error, _} = Err, _, _, _, _, _, _, _) ->
    Err;
dispatch_one(realm, {ok, Acc}, FileId, Realm, Issuer, Cek,
             OriginSealed, BatchId, _DidKeys) ->
    do_realm_scope(Acc, FileId, Realm, Issuer, Cek,
                   OriginSealed, BatchId);
dispatch_one(<<"realm">>, Acc0, FileId, Realm, Issuer, Cek,
             OriginSealed, BatchId, DidKeys) ->
    dispatch_one(realm, Acc0, FileId, Realm, Issuer, Cek,
                 OriginSealed, BatchId, DidKeys);
dispatch_one(Did, {ok, Acc}, FileId, Realm, Issuer, Cek,
             OriginSealed, BatchId, DidKeys)
  when is_binary(Did) ->
    case maps:find(Did, DidKeys) of
        {ok, PubKey} ->
            do_did_scope(Acc, FileId, Realm, Issuer, Did, PubKey,
                         Cek, OriginSealed, BatchId);
        error ->
            {error, {pubkey_not_found, Did}}
    end;
dispatch_one(Other, _, _, _, _, _, _, _, _) ->
    {error, {bad_recipient, Other}}.

do_realm_scope(Acc, FileId, Realm, Issuer, Cek, OriginSealed, BatchId) ->
    case hecate_realm_crypto:wrap(Realm, Cek) of
        {ok, WrappedCek} ->
            Grantee = <<"mri:realm:", Realm/binary>>,
            build_and_dispatch(
                Acc, FileId, Realm, Issuer, Grantee,
                realm_key_v1, WrappedCek, OriginSealed,
                k_realm_version(Realm), BatchId);
        {error, _} = Err ->
            Err
    end.

do_did_scope(Acc, FileId, Realm, Issuer, Grantee, PubKey,
             Cek, OriginSealed, BatchId) ->
    case hecate_did_crypto:wrap_for_pubkey(PubKey, Cek) of
        {ok, WrappedCek} ->
            build_and_dispatch(
                Acc, FileId, Realm, Issuer, Grantee,
                did_x25519_v1, WrappedCek, OriginSealed,
                undefined, BatchId);
        {error, _} = Err ->
            Err
    end.

build_and_dispatch(Acc, FileId, Realm, Issuer, Grantee,
                   WrapStrategy, WrappedCek, OriginSealed,
                   KRealmVersion, BatchId) ->
    LicenseId = gen_id(<<"lic-">>),
    Now = erlang:system_time(millisecond),
    Params = #{
        license_id        => LicenseId,
        file_id           => FileId,
        grantee           => Grantee,
        wrap_strategy     => WrapStrategy,
        wrapped_cek       => WrappedCek,
        origin_cek_sealed => OriginSealed,
        k_realm_version   => KRealmVersion,
        issuer_did        => Issuer,
        realm             => Realm,
        batch_id          => BatchId,
        issued_at         => Now,
        expires_at        => Now + ten_years_ms()},
    case issue_license_v1:new(Params) of
        {ok, Cmd} ->
            case maybe_issue_license:dispatch(Cmd) of
                {ok, _V, _Events} -> {ok, [LicenseId | Acc]};
                {error, _} = Err -> Err
            end;
        {error, _} = Err ->
            Err
    end.

finish(BatchId, {ok, LicenseIds}) ->
    {ok, #{batch_id    => BatchId,
           license_ids => lists:reverse(LicenseIds)}};
finish(_BatchId, {error, _} = Err) ->
    Err.

resolve_pubkeys(_Realm, []) ->
    {ok, #{}};
resolve_pubkeys(Realm, Dids) ->
    case erlang:whereis(hecate_mesh_client) of
        undefined ->
            {error, mesh_not_ready};
        _Pid ->
            call_and_decode(Realm, Dids)
    end.

call_and_decode(Realm, Dids) ->
    case hecate_mesh:call(?PUBKEY_RPC,
                         #{realm => Realm, mris => Dids},
                         ?PUBKEY_RPC_TIMEOUT) of
        {ok, Result} ->
            decode_pubkey_result(Dids, Result);
        {error, _} = Err ->
            Err
    end.

decode_pubkey_result(Dids, #{<<"entries">> := Entries}) when is_list(Entries) ->
    {ok, build_pubkey_map(Dids, Entries)};
decode_pubkey_result(Dids, #{entries := Entries}) when is_list(Entries) ->
    {ok, build_pubkey_map(Dids, Entries)};
decode_pubkey_result(_Dids, Other) ->
    {error, {unexpected_rpc_shape, Other}}.

build_pubkey_map(_Dids, Entries) ->
    lists:foldl(
        fun(Entry, Acc) ->
            case decode_entry(Entry) of
                {ok, Mri, Pub} -> Acc#{Mri => Pub};
                error -> Acc
            end
        end, #{}, Entries).

decode_entry(#{<<"mri">> := Mri, <<"encryption_public_key">> := Pub}) ->
    decode_entry_bin(Mri, Pub);
decode_entry(#{mri := Mri, encryption_public_key := Pub}) ->
    decode_entry_bin(Mri, Pub);
decode_entry(_) ->
    error.

decode_entry_bin(Mri, Pub) when is_binary(Mri), is_binary(Pub) ->
    case maybe_b64(Pub) of
        {ok, Bin} when byte_size(Bin) == 32 -> {ok, Mri, Bin};
        _ -> error
    end;
decode_entry_bin(_, _) -> error.

%% Try base64 decode; if the value is already raw 32-byte key, use it
%% as-is. Realm server announces b64 today, kept the fallback so this
%% is resilient to API shape drift.
maybe_b64(Bin) when is_binary(Bin), byte_size(Bin) == 32 ->
    {ok, Bin};
maybe_b64(Bin) ->
    try {ok, base64:decode(Bin)}
    catch _:_ -> error
    end.

seal_origin(Cek) ->
    case hecate_crypto:encrypt(Cek) of
        {ok, Sealed} -> {ok, Sealed};
        {error, _} = Err -> Err
    end.

k_realm_version(Realm) ->
    case hecate_realm_crypto:current(Realm) of
        {ok, #{version := V}} -> V;
        _                     -> undefined
    end.

gen_id(Prefix) ->
    <<Prefix/binary, (binary_encode(crypto:strong_rand_bytes(12)))/binary>>.

binary_encode(Bin) ->
    << <<(nibble(N div 16)), (nibble(N rem 16))>> || <<N>> <= Bin >>.

nibble(N) when N < 10 -> $0 + N;
nibble(N)             -> $a + N - 10.

ten_years_ms() -> 10 * 365 * 24 * 3600 * 1000.
