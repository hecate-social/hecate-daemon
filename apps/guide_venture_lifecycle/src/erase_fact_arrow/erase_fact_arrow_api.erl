%%% @doc API handler: POST /api/ventures/:venture_id/storm/fact/:arrow_id/erase
%%%
%%% Erases a fact arrow during Big Picture Event Storming.
%%% @end
-module(erase_fact_arrow_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    ArrowId = cowboy_req:binding(arrow_id, Req0),
    case erase_fact_arrow_v1:new(#{
        venture_id => VentureId,
        arrow_id => ArrowId
    }) of
        {ok, Cmd} ->
            case maybe_erase_fact_arrow:dispatch(Cmd) of
                {ok, Version, Events} ->
                    Body2 = #{
                        venture_id => VentureId,
                        arrow_id => ArrowId,
                        version => Version,
                        events => Events
                    },
                    hecate_api_utils:json_reply(200, Body2, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(422, Reason, Req0)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.
