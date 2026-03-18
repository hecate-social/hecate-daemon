%%% @doc API handler: GET /api/briefcase/files/:file_id/blob
%%%
%%% Serves the raw file bytes for imported files.
%%% Plugin-owned files (no blob_id) return 404.
%%% @end
-module(get_file_blob_api).

-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/files/:file_id/blob", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _         -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case project_briefcase_store:get_file(FileId) of
        {ok, File} ->
            serve_blob(File, Req0);
        {error, not_found} ->
            hecate_api_utils:not_found(Req0)
    end.

serve_blob(#{blob_id := BlobId} = File, Req0) when is_binary(BlobId) ->
    BlobPath = blob_path(BlobId),
    case file:read_file(BlobPath) of
        {ok, Bytes} ->
            MimeType = maps:get(mime_type, File, <<"application/octet-stream">>),
            Req = cowboy_req:reply(200, #{
                <<"content-type">> => MimeType,
                <<"content-disposition">> => <<"inline">>
            }, Bytes, Req0),
            {ok, Req, []};
        {error, enoent} ->
            hecate_api_utils:not_found(Req0);
        {error, _Reason} ->
            hecate_api_utils:json_error(500, <<"Failed to read blob">>, Req0)
    end;
serve_blob(_File, Req0) ->
    %% Plugin-owned file, no blob stored
    hecate_api_utils:not_found(Req0).

blob_path(BlobId) ->
    filename:join([blob_dir(), BlobId]).

blob_dir() ->
    BaseDir = shared_paths:base_dir(),
    filename:join([BaseDir, "briefcase", "blobs"]).
