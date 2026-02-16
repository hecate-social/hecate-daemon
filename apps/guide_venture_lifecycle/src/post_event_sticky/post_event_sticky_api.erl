%%% @doc API handler: POST /api/ventures/:venture_id/storm/sticky
%%%
%%% Posts a new event sticky during Big Picture Event Storming.
%%% @end
-module(post_event_sticky_api).

-export([init/2, routes/0]).

routes() -> [{"/api/ventures/:venture_id/storm/sticky", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    Text = maps:get(<<"text">>, Params, undefined),
    case Text of
        undefined ->
            hecate_api_utils:json_error(400, <<"text is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"text cannot be empty">>, Req1);
        _ ->
            Author = maps:get(<<"author">>, Params, <<"user">>),
            case post_event_sticky_v1:new(#{
                venture_id => VentureId,
                text => Text,
                author => Author
            }) of
                {ok, Cmd} ->
                    case maybe_post_event_sticky:dispatch(Cmd) of
                        {ok, _Version, Events} ->
                            StickyId = extract_sticky_id(Events),
                            Body2 = #{
                                venture_id => VentureId,
                                sticky_id => StickyId,
                                text => Text,
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

extract_sticky_id([#{<<"sticky_id">> := StickyId} | _]) -> StickyId;
extract_sticky_id([#{sticky_id := StickyId} | _]) -> StickyId;
extract_sticky_id(_) -> undefined.
