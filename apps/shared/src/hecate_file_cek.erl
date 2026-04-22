%%% @doc CEK lookup for issued files.
%%%
%%% Reads the `my_issued_files` ETS (owned by `project_share_licenses`)
%%% directly by name to avoid a `shared` -> PRJ dep. Same pattern as
%%% `hecate_realm_crypto` reads `realm_shared_keys`.
%%%
%%% A recipient cannot look up the CEK this way — their CEK is carried
%%% per-license in the accepted row and unwrapped via `hecate_realm_crypto`
%%% (realm scope) or `hecate_did_crypto` (DID scope). Phase F's decrypt
%%% path handles that.
%%% @end
-module(hecate_file_cek).

-export([sealed/1, unseal/1]).

-define(TABLE, my_issued_files).

-type sealed() :: binary().
-type plaintext_cek() :: <<_:256>>.

%%====================================================================
%% API
%%====================================================================

%% @doc Sealed CEK for a `FileId` this daemon has issued licenses for,
%% or `{error, not_found}` if unknown (wasn't shared by us, or the
%% projection hasn't caught up yet).
-spec sealed(binary()) -> {ok, sealed()} | {error, not_found}.
sealed(FileId) when is_binary(FileId) ->
    case ets:whereis(?TABLE) of
        undefined -> {error, not_found};
        _ ->
            case ets:lookup(?TABLE, FileId) of
                [{_, #{origin_cek_sealed := Sealed}}] ->
                    {ok, Sealed};
                [_] ->
                    {error, not_found};
                [] ->
                    {error, not_found}
            end
    end.

%% @doc Decrypt a sealed CEK to 32-byte plaintext. Caller is
%% responsible for not logging or persisting the returned bytes.
-spec unseal(sealed()) -> {ok, plaintext_cek()} | {error, term()}.
unseal(Sealed) when is_binary(Sealed) ->
    case hecate_crypto:decrypt(Sealed) of
        {ok, Cek} when byte_size(Cek) == 32 -> {ok, Cek};
        {ok, _Bad}                          -> {error, bad_cek_size};
        {error, _} = Err                    -> Err
    end.
