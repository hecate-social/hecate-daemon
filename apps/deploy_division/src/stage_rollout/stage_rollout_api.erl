-module(stage_rollout_api).
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
    ReleaseId = maps:get(<<"release_id">>, Params, undefined),
    StageName = maps:get(<<"stage_name">>, Params, undefined),
    case {ReleaseId, StageName} of
        {undefined, _} ->
            hecate_api_utils:json_error(400, <<"release_id is required">>, Req1);
        {_, undefined} ->
            hecate_api_utils:json_error(400, <<"stage_name is required">>, Req1);
        {<<>>, _} ->
            hecate_api_utils:json_error(400, <<"release_id cannot be empty">>, Req1);
        {_, <<>>} ->
            hecate_api_utils:json_error(400, <<"stage_name cannot be empty">>, Req1);
        _ ->
            StagePercentage = maps:get(<<"stage_percentage">>, Params, 0),
            Description = maps:get(<<"description">>, Params, undefined),
            case stage_rollout_v1:new(#{
                division_id => DivisionId,
                release_id => ReleaseId,
                stage_name => StageName,
                stage_percentage => StagePercentage,
                description => Description
            }) of
                {ok, Cmd} ->
                    case maybe_stage_rollout:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            StageId = extract_stage_id(Events),
                            lists:foreach(fun(E) ->
                                rollout_staged_v1_to_pg:emit(E),
                                rollout_staged_v1_to_mesh:emit(E)
                            end, Events),
                            Body2 = #{
                                division_id => DivisionId,
                                stage_id => StageId,
                                release_id => ReleaseId,
                                stage_name => StageName,
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

extract_stage_id([#{<<"stage_id">> := StageId} | _]) -> StageId;
extract_stage_id([#{stage_id := StageId} | _]) -> StageId;
extract_stage_id(_) -> undefined.
