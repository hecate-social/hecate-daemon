-module(design_aggregate_api).
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
    AggregateName = maps:get(<<"aggregate_name">>, Params, undefined),
    case AggregateName of
        undefined ->
            hecate_api_utils:json_error(400, <<"aggregate_name is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"aggregate_name cannot be empty">>, Req1);
        _ ->
            StreamPattern = maps:get(<<"stream_pattern">>, Params, <<>>),
            StatusFlags = maps:get(<<"status_flags">>, Params, []),
            Description = maps:get(<<"description">>, Params, undefined),
            DesignedBy = maps:get(<<"designed_by">>, Params, undefined),
            case design_aggregate_v1:new(#{
                division_id => DivisionId,
                aggregate_name => AggregateName,
                stream_pattern => StreamPattern,
                status_flags => StatusFlags,
                description => Description,
                designed_by => DesignedBy
            }) of
                {ok, Cmd} ->
                    case maybe_design_aggregate:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            AggregateId = extract_aggregate_id(Events),
                            lists:foreach(fun(E) ->
                                aggregate_designed_v1_to_pg:emit(E),
                                aggregate_designed_v1_to_mesh:emit(E)
                            end, Events),
                            Body2 = #{
                                division_id => DivisionId,
                                aggregate_id => AggregateId,
                                aggregate_name => AggregateName,
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

extract_aggregate_id([#{<<"aggregate_id">> := AggId} | _]) -> AggId;
extract_aggregate_id([#{aggregate_id := AggId} | _]) -> AggId;
extract_aggregate_id(_) -> undefined.
