-module(get_briefcase_blob_api).
-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/items/:item_id/blob", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0) ->
    ItemId = cowboy_req:binding(item_id, Req0),
    case project_briefcase_store:get_item(ItemId) of
        {ok, #{kind := <<"symlink">>, path := Path, mime_type := MimeType}} when is_binary(Path) ->
            serve_file(Path, MimeType, Req0);
        {ok, _} ->
            hecate_api_utils:json_error(404, <<"not_a_symlink">>, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"not_found">>, Req0)
    end.

serve_file(Path, MimeType, Req0) ->
    PathStr = binary_to_list(Path),
    case file:read_file(PathStr) of
        {ok, Bytes} ->
            CT = case MimeType of
                undefined -> <<"application/octet-stream">>;
                null -> <<"application/octet-stream">>;
                M -> M
            end,
            Req1 = cowboy_req:reply(200, #{
                <<"content-type">> => CT,
                <<"content-disposition">> => <<"inline">>
            }, Bytes, Req0),
            {ok, Req1, []};
        {error, enoent} ->
            hecate_api_utils:json_error(404, <<"file_not_found_on_disk">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, list_to_binary(io_lib:format("~p", [Reason])), Req0)
    end.
