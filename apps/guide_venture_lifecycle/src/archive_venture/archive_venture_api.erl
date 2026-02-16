%%% @doc API handler: POST /api/ventures/:venture_id/archive
%%%
%%% Archives a venture (soft delete via compensating event).
%%% @end
-module(archive_venture_api).

-export([init/2, routes/0]).

routes() -> [{"/api/ventures/:venture_id/archive", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    case VentureId of
        undefined ->
            hecate_api_utils:bad_request(<<"venture_id is required">>, Req0);
        _ ->
            case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} ->
                    do_archive(VentureId, Params, Req1);
                {error, invalid_json, Req1} ->
                    hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_archive(VentureId, Params, Req) ->
    Reason = hecate_api_utils:get_field(reason, Params),

    CmdParams = #{
        venture_id => VentureId,
        reason => Reason
    },
    case archive_venture_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, ErrReason} -> hecate_api_utils:bad_request(ErrReason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_archive_venture:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                venture_id => archive_venture_v1:get_venture_id(Cmd),
                archived => true,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
