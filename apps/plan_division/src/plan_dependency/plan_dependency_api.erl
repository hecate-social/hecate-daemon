-module(plan_dependency_api).
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
    FromDesk = maps:get(<<"from_desk">>, Params, undefined),
    ToDesk = maps:get(<<"to_desk">>, Params, undefined),
    DependencyType = maps:get(<<"dependency_type">>, Params, undefined),
    Description = maps:get(<<"description">>, Params, undefined),
    PlannedBy = maps:get(<<"planned_by">>, Params, undefined),
    case plan_dependency_v1:new(#{
        division_id => DivisionId,
        from_desk => FromDesk,
        to_desk => ToDesk,
        dependency_type => DependencyType,
        description => Description,
        planned_by => PlannedBy
    }) of
        {ok, Cmd} ->
            case maybe_plan_dependency:dispatch(Cmd) of
                {ok, Version, Events} ->
                    DependencyId = extract_dependency_id(Events),
                    lists:foreach(fun(E) ->
                        dependency_planned_v1_to_pg:emit(E),
                        dependency_planned_v1_to_mesh:emit(E)
                    end, Events),
                    Body2 = #{
                        division_id => DivisionId,
                        dependency_id => DependencyId,
                        from_desk => FromDesk,
                        to_desk => ToDesk,
                        dependency_type => DependencyType,
                        version => Version,
                        events => Events
                    },
                    hecate_api_utils:json_reply(201, Body2, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(422, Reason, Req1)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req1)
    end.

extract_dependency_id([#{<<"dependency_id">> := DepId} | _]) -> DepId;
extract_dependency_id([#{dependency_id := DepId} | _]) -> DepId;
extract_dependency_id(_) -> undefined.
