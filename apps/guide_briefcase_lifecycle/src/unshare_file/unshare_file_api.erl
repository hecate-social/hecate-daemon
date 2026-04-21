%%% @doc API handler: POST /api/briefcase/files/:file_id/unshare
%%%
%%% Flips a local file from `shared` back to `private`. No request body.
%%% Phase A: domain event only. Phase B retracts the mesh FACT.
%%%
%%% Response: 200 JSON `{ok: true, file_id}`.
%%% @end
-module(unshare_file_api).

-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/files/:file_id/unshare", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case unshare_file(FileId) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{file_id => FileId}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.

unshare_file(FileId) when is_binary(FileId), byte_size(FileId) > 0 ->
    UnsharedAt = erlang:system_time(millisecond),
    Cmd = unshare_file_v1:new(FileId, UnsharedAt),
    maybe_unshare_file:dispatch(Cmd);
unshare_file(_) ->
    {error, file_id_required}.
