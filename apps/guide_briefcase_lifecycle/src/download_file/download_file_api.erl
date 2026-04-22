%%% @doc API handler: POST /api/briefcase/files/:file_id/download
%%%
%%% Pulls a peer's ciphertext into the local cache. Must target a row
%%% that was `file_announced_v1`'d (i.e., we have a placeholder). The
%%% handler:
%%%
%%%   1. Dispatches `download_file_v1` — the aggregate gates on
%%%      FILE_ANNOUNCED without FILE_CACHED and enforces the open-
%%%      path license guard before hitting the network.
%%%   2. The handler performs the streaming RPC + cache write
%%%      synchronously; `file_cached_v1` is emitted on success.
%%%
%%% Response: `{ok, #{file_id, bytes_written, frames}}` or 400 with
%%% the error reason (including `{license_refused, Reason}` when the
%%% guard vetoes).
%%%
%%% Large files will block the cowboy worker for the duration of the
%%% download. For Phase E this is acceptable (MVP); a background
%%% worker pool is a Phase E+ refinement.
%%% @end
-module(download_file_api).

-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/files/:file_id/download", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _          -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case download(FileId) of
        {ok, Result, _Events} ->
            hecate_api_utils:json_ok(
                maps:put(file_id, FileId, summarise(Result)),
                Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, format_error(Reason), Req0)
    end.

download(FileId) when is_binary(FileId), byte_size(FileId) > 0 ->
    case download_file_v1:new(#{file_id => FileId}) of
        {ok, Cmd} ->
            case maybe_download_file:dispatch(Cmd) of
                {ok, V, Events} -> {ok, events_to_result(Events), V};
                {error, _} = Err -> Err
            end;
        {error, _} = Err ->
            Err
    end;
download(_) ->
    {error, file_id_required}.

events_to_result([#{event_type := <<"file_cached_v1">>,
                    cache_size := Size, frames := Frames} | _]) ->
    #{bytes_written => Size, frames => Frames};
events_to_result([#{<<"event_type">> := <<"file_cached_v1">>,
                    <<"cache_size">> := Size,
                    <<"frames">> := Frames} | _]) ->
    #{bytes_written => Size, frames => Frames};
events_to_result(_) ->
    #{bytes_written => 0, frames => 0}.

summarise(#{bytes_written := _, frames := _} = R) -> R;
summarise(R) when is_map(R) -> R;
summarise(_) -> #{}.

format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason, utf8);
format_error({license_refused, Sub}) ->
    iolist_to_binary(["license_refused: ", atom_to_binary(Sub, utf8)]);
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
