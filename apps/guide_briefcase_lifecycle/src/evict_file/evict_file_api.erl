%%% @doc API handler: DELETE /api/briefcase/files/:file_id/cache
%%%
%%% Drops the local cached ciphertext for a remote file. Idempotent
%%% at the disk layer (enoent = ok), but the aggregate gates on
%%% FILE_CACHED so a DELETE on an already-evicted row returns 400
%%% (not_cached) — this lets the UI tell the difference between
%%% "evicted successfully" and "wasn't cached anyway".
%%% @end
-module(evict_file_api).

-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/files/:file_id/cache", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"DELETE">> -> handle_delete(Req0, State);
        _            -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_delete(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case evict(FileId) of
        {ok, _V, _Events} ->
            hecate_api_utils:json_ok(#{file_id => FileId,
                                       evicted => true}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, format_error(Reason), Req0)
    end.

evict(FileId) when is_binary(FileId), byte_size(FileId) > 0 ->
    case evict_file_v1:new(#{file_id => FileId}) of
        {ok, Cmd} -> maybe_evict_file:dispatch(Cmd);
        {error, _} = Err -> Err
    end;
evict(_) ->
    {error, file_id_required}.

format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason, utf8);
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
