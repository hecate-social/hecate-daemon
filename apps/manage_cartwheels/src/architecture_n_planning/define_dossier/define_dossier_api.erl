%%% @doc API handler: POST /api/cartwheels/:cartwheel_id/architecture/dossiers/define
%%%
%%% Defines a dossier during the architecture phase.
%%% @end
-module(define_dossier_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} -> do_define(Params, Req1);
        {error, invalid_json, Req1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_define(Params, Req) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        dossier_name => hecate_api_utils:get_field(dossier_name, Params),
        stream_pattern => hecate_api_utils:get_field(stream_pattern, Params, <<"default">>),
        description => hecate_api_utils:get_field(description, Params)
    },
    dispatch(define_dossier_v1, maybe_define_dossier, CmdParams, Req).

dispatch(CmdMod, HandlerMod, CmdParams, Req) ->
    case CmdMod:new(CmdParams) of
        {ok, Cmd} -> do_dispatch(HandlerMod, Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

do_dispatch(HandlerMod, Cmd, Req) ->
    case HandlerMod:dispatch(Cmd) of
        {ok, Version, Events} ->
            hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
