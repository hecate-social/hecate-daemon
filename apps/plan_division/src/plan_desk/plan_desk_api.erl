-module(plan_desk_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    DeskName = maps:get(<<"desk_name">>, Params, undefined),
    case DeskName of
        undefined ->
            hecate_api_utils:json_error(400, <<"desk_name is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"desk_name cannot be empty">>, Req1);
        _ ->
            Department = maps:get(<<"department">>, Params, <<"CMD">>),
            AggregateName = maps:get(<<"aggregate_name">>, Params, undefined),
            Description = maps:get(<<"description">>, Params, undefined),
            Priority = maps:get(<<"priority">>, Params, 0),
            PlannedBy = maps:get(<<"planned_by">>, Params, undefined),
            case plan_desk_v1:new(#{
                division_id => DivisionId,
                desk_name => DeskName,
                department => Department,
                aggregate_name => AggregateName,
                description => Description,
                priority => Priority,
                planned_by => PlannedBy
            }) of
                {ok, Cmd} ->
                    case maybe_plan_desk:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            DeskId = extract_desk_id(Events),
                            lists:foreach(fun(E) ->
                                desk_planned_v1_to_pg:emit(E),
                                desk_planned_v1_to_mesh:emit(E)
                            end, Events),
                            Body2 = #{
                                division_id => DivisionId,
                                desk_id => DeskId,
                                desk_name => DeskName,
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

extract_desk_id([#{<<"desk_id">> := DeskId} | _]) -> DeskId;
extract_desk_id([#{desk_id := DeskId} | _]) -> DeskId;
extract_desk_id(_) -> undefined.
