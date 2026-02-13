%%% @doc API handler: POST /api/ventures/:venture_id/discovery/start
%%%
%%% Starts the discovery phase for a venture.
%%% @end
-module(start_discovery_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    case start_discovery_v1:new(#{venture_id => VentureId}) of
        {ok, Cmd} ->
            case maybe_start_discovery:dispatch(Cmd) of
                {ok, Version, Events} ->
                    Body = #{
                        venture_id => VentureId,
                        version => Version,
                        events => Events
                    },
                    hecate_api_utils:json_reply(201, Body, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(422, Reason, Req0)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.
