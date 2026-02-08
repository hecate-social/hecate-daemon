%%% @doc API handler: POST /api/cartwheels/:cartwheel_id/architecture/spokes/inventory
%%%
%%% Inventories a spoke during the architecture phase.
%%% @end
-module(inventory_spoke_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} -> do_inventory(Params, Req1);
        {error, invalid_json, Req1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_inventory(Params, Req) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        spoke_name => hecate_api_utils:get_field(spoke_name, Params),
        spoke_type => hecate_api_utils:get_field(spoke_type, Params),
        priority => hecate_api_utils:get_field(priority, Params, <<"should">>),
        dossier_id => hecate_api_utils:get_field(dossier_id, Params),
        description => hecate_api_utils:get_field(description, Params)
    },
    dispatch(inventory_spoke_v1, maybe_inventory_spoke, CmdParams, Req).

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
