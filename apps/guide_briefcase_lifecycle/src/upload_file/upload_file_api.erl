%%% @doc Upload file API handler: POST /api/briefcase/files
%%%
%%% Accepts multipart/form-data with one `file` part (the binary content)
%%% and optional form fields:
%%%   - path:      logical path for the file (defaults to the upload filename)
%%%   - mime_type: MIME override (defaults to the browser-supplied Content-Type)
%%%
%%% On success:
%%%   - computes BLAKE3 of content → file_id + content_hash
%%%   - writes content to briefcase_content_store
%%%   - dispatches `upload_file_v1` command → emits `file_uploaded_v1`
%%%
%%% Response: 201 JSON `{ok: true, file_id, path, size}`.
%%% @end
-module(upload_file_api).

-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/files/upload", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case read_multipart(Req0, #{}) of
        {ok, #{file := Content} = Fields, Req1} ->
            Filename  = maps:get(filename,  Fields, <<"untitled">>),
            DefMime   = maps:get(mime_hint, Fields, <<"application/octet-stream">>),
            Path      = maps:get(path,      Fields, Filename),
            MimeType  = maps:get(mime_type, Fields, DefMime),
            process_upload(Content, Path, MimeType, Req1);
        {ok, _Fields, Req1} ->
            hecate_api_utils:json_error(400, <<"Missing file part">>, Req1);
        {error, Reason, Req1} ->
            hecate_api_utils:json_error(400, Reason, Req1)
    end.

%%% ===================================================================
%%% Internal
%%% ===================================================================

process_upload(Content, Path, MimeType, Req) ->
    FileId = macula_blake3_nif:hash_hex(Content),
    Size   = byte_size(Content),
    case briefcase_content_store:put(FileId, Content) of
        ok ->
            dispatch_upload(FileId, Path, MimeType, Size, Req);
        {error, Reason} ->
            hecate_api_utils:json_error(500, {storage_error, Reason}, Req)
    end.

dispatch_upload(FileId, Path, MimeType, Size, Req) ->
    Realm      = application:get_env(hecate, realm, <<"io.macula">>),
    AuthorDid  = hecate_identity:agent_id(),
    UploadedAt = erlang:system_time(millisecond),
    Cmd = upload_file_v1:new(FileId, Realm, to_bin(Path), to_bin(MimeType),
                             Size, FileId, AuthorDid, UploadedAt),
    case maybe_upload_file:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(
                #{file_id => FileId, path => to_bin(Path), size => Size},
                Req);
        {error, Reason} ->
            %% Content was already written; remove it to keep disk clean.
            _ = briefcase_content_store:delete(FileId),
            hecate_api_utils:json_error(400, Reason, Req)
    end.

read_multipart(Req0, Acc) ->
    case cowboy_req:read_part(Req0) of
        {ok, Headers, Req1} ->
            case cow_multipart:form_data(Headers) of
                {data, FieldName} ->
                    {ok, Body, Req2} = cowboy_req:read_part_body(Req1),
                    read_multipart(Req2,
                        Acc#{binary_to_atom(FieldName, utf8) => Body});
                {file, _FieldName, Filename, ContentType} ->
                    {ok, Body, Req2} = read_full_part_body(Req1, <<>>),
                    read_multipart(Req2,
                        Acc#{file      => Body,
                             filename  => Filename,
                             mime_hint => ContentType})
            end;
        {done, Req1} ->
            {ok, Acc, Req1}
    end.

read_full_part_body(Req0, Acc) ->
    case cowboy_req:read_part_body(Req0) of
        {ok, Body, Req1} ->
            {ok, <<Acc/binary, Body/binary>>, Req1};
        {more, Body, Req1} ->
            read_full_part_body(Req1, <<Acc/binary, Body/binary>>)
    end.

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L)   -> list_to_binary(L).
