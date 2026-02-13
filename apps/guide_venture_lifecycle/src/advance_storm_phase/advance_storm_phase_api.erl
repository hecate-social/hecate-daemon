%%% @doc API handler: POST /api/ventures/:venture_id/storm/phase/advance
%%%
%%% Advances the storm phase during Big Picture Event Storming.
%%% @end
-module(advance_storm_phase_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    TargetPhase = maps:get(<<"target_phase">>, Params, undefined),
    case TargetPhase of
        undefined ->
            hecate_api_utils:json_error(400, <<"target_phase is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"target_phase cannot be empty">>, Req1);
        _ ->
            case advance_storm_phase_v1:new(#{
                venture_id => VentureId,
                target_phase => TargetPhase
            }) of
                {ok, Cmd} ->
                    case maybe_advance_storm_phase:dispatch(Cmd) of
                        {ok, _Version, Events} ->
                            Body2 = #{
                                venture_id => VentureId,
                                target_phase => TargetPhase,
                                events => Events
                            },
                            hecate_api_utils:json_reply(201, Body2, Req1);
                        {error, Reason} ->
                            hecate_api_utils:json_error(422, Reason, Req1)
                    end;
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end
    end.
