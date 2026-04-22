%%% @doc API handler: GET /api/briefcase/files/:id/content
%%%
%%% Streams raw bytes for a briefcase file. Content is served with
%%% the Content-Type from the stored metadata, defaulting to
%%% `application/octet-stream` when absent.
%%%
%%% ## Authorisation
%%%
%%% Rows with `presence = <<"local">>` are files this daemon uploaded
%%% — owner access, no license required.
%%%
%%% Rows with `presence = <<"remote">>` are files announced by a peer.
%%% Serving them requires an accepted share-license whose state passes
%%% `hecate_license_guard:can_open_file/2`: not expired, CEK_USABLE bit
%%% set (i.e., not ended / revoked), and the per-realm
%%% `last_license_catchup_at` stamp is within the staleness threshold
%%% (default 24h). Every other case returns 403 with a JSON error
%%% identifying the specific refusal reason.
%%%
%%% Rows with `presence = <<"cached">>` are remote files whose
%%% ciphertext is available in `cache/{XX}/{FileId}.enc`. Phase F
%%% streams them back to the client decrypted on-the-fly:
%%%
%%%   1. Guard passes (as above).
%%%   2. Accepted license's `wrapped_cek` is unwrapped per
%%%      `wrap_strategy` (realm_key_v1 -> hecate_realm_crypto;
%%%      did_x25519_v1 -> recipient's X25519 private key).
%%%   3. Cache `.enc` is opened; each frame is decoded + decrypted
%%%      chunk-by-chunk via `hecate_file_frame:decrypt_envelope/2`.
%%%   4. Plaintext chunks are streamed to cowboy with
%%%      `Cache-Control: no-store` so they don't leak to browser
%%%      caches.
%%%
%%% Plaintext NEVER touches disk on the recipient side — it lives
%%% only in the per-chunk envelope while streaming.
%%%
%%% NOTE: content_path duplicated from briefcase_content_store to keep
%%% query_briefcase_files free of a cross-layer dep on
%%% guide_briefcase_lifecycle. A follow-up PR may unify both into a
%%% shared storage module.
%%% @end
-module(get_file_content_api).

-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/files/:id/content", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _         -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    FileId = cowboy_req:binding(id, Req0),
    case project_briefcase_files_store:get(FileId) of
        {ok, Entry} ->
            authorise_and_serve(FileId, Entry, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"File not found">>, Req0)
    end.

authorise_and_serve(FileId, Entry, Req0) ->
    MimeType = maps:get(mime_type, Entry, undefined),
    case maps:get(presence, Entry, <<"local">>) of
        <<"local">> ->
            serve_content(FileId, MimeType, Req0);
        <<"remote">> ->
            gate_and_then(FileId, Entry, Req0,
                fun(_Realm) ->
                    hecate_api_utils:json_error(404,
                        <<"Remote file not cached locally — download first">>,
                        Req0)
                end);
        <<"downloading">> ->
            %% Async download in flight — surface progress so the UI
            %% can render a "wait" state. 202 is REST's "resource
            %% will be available soon".
            Progress = case briefcase_download_progress:get(FileId) of
                {ok, Row} -> Row;
                _         -> #{}
            end,
            hecate_api_utils:json_ok(202,
                #{file_id       => FileId,
                  state         => <<"downloading">>,
                  bytes_written => maps:get(bytes_written, Progress, 0),
                  total_size    => maps:get(total_size_hint, Progress, null)},
                Req0);
        <<"cached">> ->
            gate_and_then(FileId, Entry, Req0,
                fun(Realm) ->
                    decrypt_and_stream(FileId, Realm, MimeType, Req0)
                end);
        _Other ->
            serve_content(FileId, MimeType, Req0)
    end.

gate_and_then(FileId, Entry, Req0, OnOk) ->
    case remote_realm(Entry) of
        {ok, Realm} ->
            case hecate_license_guard:can_open_file(FileId, Realm) of
                ok -> OnOk(Realm);
                {error, Reason} -> refusal(Reason, Req0)
            end;
        {error, missing_realm} ->
            hecate_api_utils:json_error(500,
                <<"File row missing realm">>, Req0)
    end.

remote_realm(#{realm := Realm}) when is_binary(Realm), byte_size(Realm) > 0 ->
    {ok, Realm};
remote_realm(_) ->
    {error, missing_realm}.

refusal(no_license, Req0) ->
    hecate_api_utils:json_error(403,
        <<"No accepted license for this file">>, Req0);
refusal(license_expired, Req0) ->
    hecate_api_utils:json_error(403, <<"License expired">>, Req0);
refusal(license_not_usable, Req0) ->
    hecate_api_utils:json_error(403,
        <<"License ended or revoked">>, Req0);
refusal(license_state_stale, Req0) ->
    hecate_api_utils:json_error(403,
        <<"License state stale — reconnect to the realm to refresh">>,
        Req0);
refusal(license_realm_mismatch, Req0) ->
    hecate_api_utils:json_error(403,
        <<"License realm does not match file realm">>, Req0);
refusal(license_no_expiry, Req0) ->
    hecate_api_utils:json_error(403,
        <<"License has no expiry — refusing open">>, Req0);
refusal(Other, Req0) ->
    Msg = iolist_to_binary(
            ["License refused: ", io_lib:format("~p", [Other])]),
    hecate_api_utils:json_error(403, Msg, Req0).

serve_content(FileId, MimeType, Req0) ->
    case file:read_file(content_path(FileId)) of
        {ok, Body} ->
            Headers = #{
                <<"content-type">>   => mime_or_default(MimeType),
                <<"content-length">> => integer_to_binary(byte_size(Body))
            },
            cowboy_req:reply(200, Headers, Body, Req0);
        {error, enoent} ->
            hecate_api_utils:json_error(404,
                <<"Content not locally available on this peer">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

content_path(FileId) when is_binary(FileId), byte_size(FileId) >= 2 ->
    Prefix = binary:part(FileId, 0, 2),
    SubDir = filename:join(
        [shared_paths:base_dir(), "briefcase/content",
         binary_to_list(Prefix)]),
    Name = <<FileId/binary, ".bin">>,
    filename:join(SubDir, binary_to_list(Name)).

mime_or_default(undefined) -> <<"application/octet-stream">>;
mime_or_default(Mime) when is_binary(Mime) -> Mime;
mime_or_default(Mime) when is_list(Mime) -> list_to_binary(Mime).

%%====================================================================
%% Phase F: decrypt-on-use streaming
%%====================================================================

decrypt_and_stream(FileId, Realm, MimeType, Req0) ->
    case project_share_licenses_store:get_accepted_by_file_id(FileId) of
        {ok, License} ->
            with_cek(License, Realm, fun(Cek) ->
                open_and_stream(FileId, Cek, MimeType, Req0)
            end, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(403,
                <<"No accepted license found for this file">>, Req0)
    end.

with_cek(License, Realm, OnOk, Req0) ->
    case unwrap_cek(License, Realm) of
        {ok, Cek} -> OnOk(Cek);
        {error, Reason} ->
            Msg = iolist_to_binary(
                    ["CEK unwrap failed: ",
                     io_lib:format("~p", [Reason])]),
            hecate_api_utils:json_error(500, Msg, Req0)
    end.

unwrap_cek(#{wrap_strategy := realm_key_v1, wrapped_cek := WC}, Realm) ->
    hecate_realm_crypto:unwrap(Realm, WC);
unwrap_cek(#{wrap_strategy := did_x25519_v1, wrapped_cek := WC}, _Realm) ->
    case hecate_identity:encryption_keypair() of
        {ok, {_Pub, Priv}} ->
            hecate_did_crypto:unwrap_with_privkey(Priv, WC);
        not_initialized ->
            {error, encryption_keypair_not_ready}
    end;
unwrap_cek(_License, _Realm) ->
    {error, unknown_wrap_strategy}.

open_and_stream(FileId, Cek, MimeType, Req0) ->
    case briefcase_cache_store:open_reader(FileId) of
        {ok, Fd} ->
            Result = stream_decrypted(Fd, Cek, MimeType, Req0),
            ok = briefcase_cache_store:close_reader(Fd),
            Result;
        {error, enoent} ->
            hecate_api_utils:json_error(404,
                <<"Cache file missing — re-download">>, Req0);
        {error, Reason} ->
            Msg = iolist_to_binary(io_lib:format("~p", [Reason])),
            hecate_api_utils:json_error(500, Msg, Req0)
    end.

stream_decrypted(Fd, Cek, MimeType, Req0) ->
    Headers = #{
        <<"content-type">>   => mime_or_default(MimeType),
        <<"cache-control">>  => <<"no-store">>,
        %% Length unknown up-front — chunked transfer.
        <<"transfer-encoding">> => <<"chunked">>
    },
    Req1 = cowboy_req:stream_reply(200, Headers, Req0),
    pump_decrypt(Fd, Cek, Req1).

pump_decrypt(Fd, Cek, Req) ->
    case briefcase_cache_store:read_exact(Fd, 4) of
        {ok, <<0:32/big>>} ->
            %% EOF frame.
            cowboy_req:stream_body(<<>>, fin, Req),
            Req;
        {ok, <<Len:32/big>>} ->
            case briefcase_cache_store:read_exact(Fd, Len) of
                {ok, Envelope} ->
                    case hecate_file_frame:decrypt_envelope(Cek, Envelope) of
                        {ok, Plain} ->
                            cowboy_req:stream_body(Plain, nofin, Req),
                            pump_decrypt(Fd, Cek, Req);
                        {error, _} ->
                            %% Already streamed headers + maybe chunks;
                            %% best we can do is close without fin
                            %% (client sees truncated response).
                            cowboy_req:stream_body(<<>>, fin, Req),
                            Req
                    end;
                _ ->
                    cowboy_req:stream_body(<<>>, fin, Req),
                    Req
            end;
        eof ->
            %% Unexpected: file ended without EOF frame. Close anyway.
            cowboy_req:stream_body(<<>>, fin, Req),
            Req;
        {error, _} ->
            cowboy_req:stream_body(<<>>, fin, Req),
            Req
    end.
