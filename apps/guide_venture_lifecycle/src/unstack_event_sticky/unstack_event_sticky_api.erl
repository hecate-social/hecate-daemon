%%% @doc API handler: POST /api/ventures/:venture_id/storm/sticky/:sticky_id/unstack
%%%
%%% Removes an event sticky from its stack during Big Picture Event Storming.
%%% @end
-module(unstack_event_sticky_api).

-export([init/2, routes/0]).

routes() -> [{"/api/ventures/:venture_id/storm/sticky/:sticky_id/unstack", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    StickyId = cowboy_req:binding(sticky_id, Req0),
    case unstack_event_sticky_v1:new(#{
        venture_id => VentureId,
        sticky_id => StickyId
    }) of
        {ok, Cmd} ->
            case maybe_unstack_event_sticky:dispatch(Cmd) of
                {ok, _Version, Events} ->
                    Body = #{
                        venture_id => VentureId,
                        sticky_id => StickyId,
                        events => Events
                    },
                    hecate_api_utils:json_reply(201, Body, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(422, Reason, Req0)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.
