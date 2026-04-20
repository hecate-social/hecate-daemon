%%% @doc API handler: GET /api/briefcase/files/:id/content
%%%
%%% Streams raw bytes for a briefcase file. Content is served with
%%% the Content-Type from the stored metadata, defaulting to
%%% `application/octet-stream` when absent.
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
        {ok, #{mime_type := MimeType}} ->
            serve_content(FileId, MimeType, Req0);
        {ok, _EntryWithoutMime} ->
            serve_content(FileId, undefined, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"File not found">>, Req0)
    end.

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
