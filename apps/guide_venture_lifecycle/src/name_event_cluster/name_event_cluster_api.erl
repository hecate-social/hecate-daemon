%%% @doc API handler: POST /api/ventures/:venture_id/storm/cluster/:cluster_id/name
%%%
%%% Names an event cluster during Big Picture Event Storming.
%%% @end
-module(name_event_cluster_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    ClusterId = cowboy_req:binding(cluster_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    Name = maps:get(<<"name">>, Params, undefined),
    case Name of
        undefined ->
            hecate_api_utils:json_error(400, <<"name is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"name cannot be empty">>, Req1);
        _ ->
            case name_event_cluster_v1:new(#{
                venture_id => VentureId,
                cluster_id => ClusterId,
                name => Name
            }) of
                {ok, Cmd} ->
                    case maybe_name_event_cluster:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            Body2 = #{
                                venture_id => VentureId,
                                cluster_id => ClusterId,
                                name => Name,
                                version => Version,
                                events => Events
                            },
                            hecate_api_utils:json_reply(200, Body2, Req1);
                        {error, Reason} ->
                            hecate_api_utils:json_error(422, Reason, Req1)
                    end;
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end
    end.
