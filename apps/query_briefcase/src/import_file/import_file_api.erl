%%% @doc API handler: POST /api/briefcase/files/import
%%%
%%% Imports a file from base64-encoded bytes:
%%%   1. Decodes base64 payload
%%%   2. Writes blob to disk
%%%   3. Dispatches import_file_v1 command to the file aggregate
%%% @end
-module(import_file_api).

-export([init/2, routes/0]).

-include_lib("evoq/include/evoq.hrl").

routes() -> [{"/api/briefcase/files/import", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            do_import(Body, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_import(Body, Req) ->
    Name = hecate_api_utils:get_field(name, Body),
    BytesB64 = hecate_api_utils:get_field(bytes, Body),
    case {Name, BytesB64} of
        {undefined, _} ->
            hecate_api_utils:bad_request(<<"name is required">>, Req);
        {_, undefined} ->
            hecate_api_utils:bad_request(<<"bytes is required">>, Req);
        _ ->
            import_with_blob(Name, BytesB64, Body, Req)
    end.

import_with_blob(Name, BytesB64, Body, Req) ->
    case decode_base64(BytesB64) of
        {ok, Bytes} ->
            BlobId = generate_blob_id(),
            BlobDir = blob_dir(),
            ok = filelib:ensure_path(BlobDir),
            BlobPath = filename:join(BlobDir, BlobId),
            case file:write_file(BlobPath, Bytes) of
                ok ->
                    dispatch_import(Name, BlobId, byte_size(Bytes), Body, Req);
                {error, WriteErr} ->
                    hecate_api_utils:json_error(500, iolist_to_binary(
                        io_lib:format("Failed to write blob: ~p", [WriteErr])), Req)
            end;
        {error, _} ->
            hecate_api_utils:bad_request(<<"Invalid base64 in bytes field">>, Req)
    end.

dispatch_import(Name, BlobId, Size, Body, Req) ->
    FileId = generate_file_id(),
    FolderId = hecate_api_utils:get_field(folder_id, Body),
    {FileType, MimeType} = detect_file_type(Name),
    Now = erlang:system_time(millisecond),
    Payload = #{
        command_type => <<"import_file">>,
        file_id => FileId,
        name => Name,
        folder_id => FolderId,
        file_type => FileType,
        blob_id => BlobId,
        size => Size,
        mime_type => MimeType,
        created_at => Now
    },
    EvoqCmd = #evoq_command{
        command_type = import_file,
        aggregate_type = file_aggregate,
        aggregate_id = FileId,
        payload = Payload,
        metadata = #{timestamp => Now}
    },
    case evoq_dispatcher:dispatch(EvoqCmd, dispatch_opts()) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(201, #{ok => true, file_id => FileId}, Req);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req)
    end.

decode_base64(B64) when is_binary(B64) ->
    try
        {ok, base64:decode(B64)}
    catch
        _:_ -> {error, invalid_base64}
    end;
decode_base64(_) ->
    {error, invalid_base64}.

detect_file_type(Name) ->
    Ext = string:lowercase(filename:extension(binary_to_list(Name))),
    case Ext of
        ".pdf"  -> {<<"pdf">>,      <<"application/pdf">>};
        ".jpg"  -> {<<"image">>,     <<"image/jpeg">>};
        ".jpeg" -> {<<"image">>,     <<"image/jpeg">>};
        ".png"  -> {<<"image">>,     <<"image/png">>};
        ".gif"  -> {<<"image">>,     <<"image/gif">>};
        ".svg"  -> {<<"image">>,     <<"image/svg+xml">>};
        ".webp" -> {<<"image">>,     <<"image/webp">>};
        ".md"   -> {<<"markdown">>,  <<"text/markdown">>};
        ".txt"  -> {<<"text">>,      <<"text/plain">>};
        ".csv"  -> {<<"csv">>,       <<"text/csv">>};
        ".json" -> {<<"json">>,      <<"application/json">>};
        ".zip"  -> {<<"archive">>,   <<"application/zip">>};
        ".tar"  -> {<<"archive">>,   <<"application/x-tar">>};
        ".gz"   -> {<<"archive">>,   <<"application/gzip">>};
        ".mp3"  -> {<<"audio">>,     <<"audio/mpeg">>};
        ".mp4"  -> {<<"video">>,     <<"video/mp4">>};
        ".html" -> {<<"html">>,      <<"text/html">>};
        _       -> {<<"file">>,      <<"application/octet-stream">>}
    end.

generate_file_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Hex = binary:encode_hex(crypto:strong_rand_bytes(2)),
    <<"file-", Ts/binary, "-", Hex/binary>>.

generate_blob_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Hex = binary:encode_hex(crypto:strong_rand_bytes(2)),
    <<"blob-", Ts/binary, "-", Hex/binary>>.

blob_dir() ->
    BaseDir = shared_paths:base_dir(),
    filename:join([BaseDir, "briefcase", "blobs"]).

dispatch_opts() ->
    #{
        store_id => briefcase_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }.
