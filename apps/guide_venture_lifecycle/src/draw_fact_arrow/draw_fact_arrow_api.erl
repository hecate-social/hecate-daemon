%%% @doc API handler: POST /api/ventures/:venture_id/storm/fact
%%%
%%% Draws a fact arrow between clusters during Big Picture Event Storming.
%%% @end
-module(draw_fact_arrow_api).

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
    FromCluster = maps:get(<<"from_cluster">>, Params, undefined),
    ToCluster = maps:get(<<"to_cluster">>, Params, undefined),
    FactName = maps:get(<<"fact_name">>, Params, undefined),
    case {FromCluster, ToCluster, FactName} of
        {undefined, _, _} ->
            hecate_api_utils:json_error(400, <<"from_cluster is required">>, Req1);
        {_, undefined, _} ->
            hecate_api_utils:json_error(400, <<"to_cluster is required">>, Req1);
        {_, _, undefined} ->
            hecate_api_utils:json_error(400, <<"fact_name is required">>, Req1);
        _ ->
            case draw_fact_arrow_v1:new(#{
                venture_id => VentureId,
                from_cluster => FromCluster,
                to_cluster => ToCluster,
                fact_name => FactName
            }) of
                {ok, Cmd} ->
                    case maybe_draw_fact_arrow:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            ArrowId = extract_arrow_id(Events),
                            Body2 = #{
                                venture_id => VentureId,
                                arrow_id => ArrowId,
                                from_cluster => FromCluster,
                                to_cluster => ToCluster,
                                fact_name => FactName,
                                version => Version,
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

extract_arrow_id([#{<<"arrow_id">> := ArrowId} | _]) -> ArrowId;
extract_arrow_id([#{arrow_id := ArrowId} | _]) -> ArrowId;
extract_arrow_id(_) -> undefined.
