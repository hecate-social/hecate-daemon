%%% @doc API handler: POST /api/ventures/:venture_id/storm/stack/:stack_id/groom
%%%
%%% Grooms a stack by picking a canonical sticky during Big Picture Event Storming.
%%% @end
-module(groom_event_stack_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    StackId = cowboy_req:binding(stack_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CanonicalStickyId = maps:get(<<"canonical_sticky_id">>, Params, undefined),
    case CanonicalStickyId of
        undefined ->
            hecate_api_utils:json_error(400, <<"canonical_sticky_id is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"canonical_sticky_id cannot be empty">>, Req1);
        _ ->
            case groom_event_stack_v1:new(#{
                venture_id => VentureId,
                stack_id => StackId,
                canonical_sticky_id => CanonicalStickyId
            }) of
                {ok, Cmd} ->
                    case maybe_groom_event_stack:dispatch(Cmd) of
                        {ok, _Version, Events} ->
                            Body2 = #{
                                venture_id => VentureId,
                                stack_id => StackId,
                                canonical_sticky_id => CanonicalStickyId,
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
