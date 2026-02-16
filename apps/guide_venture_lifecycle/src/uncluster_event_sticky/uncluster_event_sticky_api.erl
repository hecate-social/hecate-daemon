%%% @doc API handler: POST /api/ventures/:venture_id/storm/sticky/:sticky_id/uncluster
%%%
%%% Removes an event sticky from its cluster during Big Picture Event Storming.
%%% @end
-module(uncluster_event_sticky_api).

-export([init/2, routes/0]).

routes() -> [{"/api/ventures/:venture_id/storm/sticky/:sticky_id/uncluster", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    StickyId = cowboy_req:binding(sticky_id, Req0),
    case uncluster_event_sticky_v1:new(#{
        venture_id => VentureId,
        sticky_id => StickyId
    }) of
        {ok, Cmd} ->
            case maybe_uncluster_event_sticky:dispatch(Cmd) of
                {ok, Version, Events} ->
                    Body2 = #{
                        venture_id => VentureId,
                        sticky_id => StickyId,
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
