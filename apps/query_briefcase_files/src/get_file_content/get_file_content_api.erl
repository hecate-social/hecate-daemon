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
%%% Phase A (this wiring) serves plaintext bytes when the guard passes.
%%% Phase E+F will replace the plaintext read with chunk-wise decrypt
%%% using the license's sealed CEK.
%%%
%%% NOTE: content_path duplicated from briefcase_content_store to keep
%%% query_briefcase_files free of a cross-layer dep on
%%% guide_briefcase_lifecycle. A follow-up PR may unify both into a
%%% shared storage module once a second reader emerges (e.g. mesh
%%% RPC handler `briefcase.get_chunk`).
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
            gate_remote_and_serve(FileId, Entry, MimeType, Req0);
        _Other ->
            serve_content(FileId, MimeType, Req0)
    end.

gate_remote_and_serve(FileId, Entry, MimeType, Req0) ->
    case remote_realm(Entry) of
        {ok, Realm} ->
            case hecate_license_guard:can_open_file(FileId, Realm) of
                ok -> serve_content(FileId, MimeType, Req0);
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
