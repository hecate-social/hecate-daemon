%%% @doc API handler: POST /api/ventures/:venture_id/discovery/pause
%%%
%%% Pauses the discovery phase for a venture.
%%% @end
-module(pause_discovery_api).

-export([init/2, routes/0]).

routes() -> [{"/api/ventures/:venture_id/discovery/pause", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    Reason = case cowboy_req:has_body(Req0) of
        true ->
            {ok, Body, _} = cowboy_req:read_body(Req0),
            Params = json:decode(Body),
            maps:get(<<"reason">>, Params, undefined);
        false -> undefined
    end,
    case pause_discovery_v1:new(#{venture_id => VentureId, reason => Reason}) of
        {ok, Cmd} ->
            case maybe_pause_discovery:dispatch(Cmd) of
                {ok, Version, Events} ->
                    hecate_api_utils:json_reply(200, #{
                        venture_id => VentureId,
                        paused => true,
                        version => Version,
                        events => Events
                    }, Req0);
                {error, Reason2} ->
                    hecate_api_utils:json_error(422, Reason2, Req0)
            end;
        {error, Reason3} ->
            hecate_api_utils:json_error(400, Reason3, Req0)
    end.
