%%% @doc API handler: POST /api/cartwheels/:cartwheel_id/deployment/incident
%%%
%%% Reports an incident for a cartwheel.
%%% @end
-module(report_incident_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} -> do_report(Params, Req1);
        {error, invalid_json, Req1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_report(Params, Req) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        severity => hecate_api_utils:get_field(severity, Params, <<"medium">>),
        description => hecate_api_utils:get_field(description, Params)
    },
    dispatch(CmdParams, Req).

dispatch(CmdParams, Req) ->
    case report_incident_v1:new(CmdParams) of
        {ok, Cmd} -> do_dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

do_dispatch(Cmd, Req) ->
    case maybe_report_incident:dispatch(Cmd) of
        {ok, Version, Events} ->
            hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
