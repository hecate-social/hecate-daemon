%%% @doc API handler: POST /alc/projects/initiate (legacy)
%%%
%%% Initiates a new cartwheel directly (legacy ALC route).
%%% Note: The preferred flow is Torch → identify_cartwheel → mesh → initiate.
%%% This endpoint exists for backward compatibility.
%%% @end
-module(initiate_cartwheel_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_initiate(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_initiate(Params, Req) ->
    CmdParams = #{
        context_name => get_name(Params),
        torch_id => hecate_api_utils:get_field(torch_id, Params),
        description => hecate_api_utils:get_field(description, Params)
    },
    case initiate_cartwheel_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

get_name(Params) ->
    case hecate_api_utils:get_field(name, Params) of
        undefined -> hecate_api_utils:get_field(context_name, Params);
        Name -> Name
    end.

dispatch(Cmd, Req) ->
    case maybe_initiate_cartwheel:dispatch(Cmd) of
        {ok, Version, Events} ->
            hecate_api_utils:json_ok(201, #{
                cartwheel_id => initiate_cartwheel_v1:get_cartwheel_id(Cmd),
                version => Version,
                events => Events
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
