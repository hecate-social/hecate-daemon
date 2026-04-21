%%% @doc API handler: POST /api/briefcase/files/:file_id/share
%%%
%%% Flips a local file from `private` to `shared`. No request body
%%% needed. Phase A: domain event only. Phase B adds the mesh FACT
%%% emission so peers receive the placeholder.
%%%
%%% Response: 200 JSON `{ok: true, file_id}`.
%%% @end
-module(share_file_api).

-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/files/:file_id/share", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case share_file(FileId) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{file_id => FileId}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.

share_file(FileId) when is_binary(FileId), byte_size(FileId) > 0 ->
    SharedAt = erlang:system_time(millisecond),
    Cmd = share_file_v1:new(FileId, SharedAt),
    maybe_share_file:dispatch(Cmd);
share_file(_) ->
    {error, file_id_required}.
