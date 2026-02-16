%%% @doc API handler: POST /api/ventures/:venture_id/storm/sticky/:sticky_id/stack
%%%
%%% Stacks an event sticky onto a target sticky during Big Picture Event Storming.
%%% @end
-module(stack_event_sticky_api).

-export([init/2, routes/0]).

routes() -> [{"/api/ventures/:venture_id/storm/sticky/:sticky_id/stack", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    StickyId = cowboy_req:binding(sticky_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    TargetStickyId = maps:get(<<"target_sticky_id">>, Params, undefined),
    case TargetStickyId of
        undefined ->
            hecate_api_utils:json_error(400, <<"target_sticky_id is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"target_sticky_id cannot be empty">>, Req1);
        _ ->
            case stack_event_sticky_v1:new(#{
                venture_id => VentureId,
                sticky_id => StickyId,
                target_sticky_id => TargetStickyId
            }) of
                {ok, Cmd} ->
                    case maybe_stack_event_sticky:dispatch(Cmd) of
                        {ok, _Version, Events} ->
                            Body2 = #{
                                venture_id => VentureId,
                                sticky_id => StickyId,
                                target_sticky_id => TargetStickyId,
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
