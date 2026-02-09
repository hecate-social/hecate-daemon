%%% @doc API handler: POST /api/torches/:torch_id/archive
%%%
%%% Archives a torch (soft delete via compensating event).
%%% Lives in the archive_torch spoke for vertical slicing.
%%% @end
-module(archive_torch_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    TorchId = cowboy_req:binding(torch_id, Req0),
    case TorchId of
        undefined ->
            hecate_api_utils:bad_request(<<"torch_id is required">>, Req0);
        _ ->
            case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} ->
                    do_archive(TorchId, Params, Req1);
                {error, invalid_json, Req1} ->
                    hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_archive(TorchId, Params, Req) ->
    ArchivedBy = hecate_api_utils:get_field(archived_by, Params),
    Reason = hecate_api_utils:get_field(reason, Params),

    CmdParams = #{
        torch_id => TorchId,
        archived_by => ArchivedBy,
        reason => Reason
    },
    case archive_torch_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_archive_torch:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            %% INTERNAL: Emit to pg for projections (intra-daemon)
            emit_to_pg(EventMaps),
            hecate_api_utils:json_ok(200, #{
                torch_id => archive_torch_v1:get_torch_id(Cmd),
                archived => true,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

emit_to_pg(EventMaps) ->
    lists:foreach(fun(E) ->
        torch_archived_v1_to_pg:emit(E)
    end, EventMaps).
