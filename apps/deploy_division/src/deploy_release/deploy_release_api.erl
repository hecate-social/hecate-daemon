-module(deploy_release_api).
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
    ReleaseName = maps:get(<<"release_name">>, Params, undefined),
    case ReleaseName of
        undefined ->
            hecate_api_utils:json_error(400, <<"release_name is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"release_name cannot be empty">>, Req1);
        _ ->
            ReleaseVersion = maps:get(<<"release_version">>, Params, <<>>),
            TargetEnv = maps:get(<<"target_env">>, Params, <<>>),
            DeployedBy = maps:get(<<"deployed_by">>, Params, undefined),
            case deploy_release_v1:new(#{
                division_id => DivisionId,
                release_name => ReleaseName,
                release_version => ReleaseVersion,
                target_env => TargetEnv,
                deployed_by => DeployedBy
            }) of
                {ok, Cmd} ->
                    case maybe_deploy_release:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            ReleaseId = extract_release_id(Events),
                            lists:foreach(fun(E) ->
                                release_deployed_v1_to_pg:emit(E),
                                release_deployed_v1_to_mesh:emit(E)
                            end, Events),
                            Body2 = #{
                                division_id => DivisionId,
                                release_id => ReleaseId,
                                release_name => ReleaseName,
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

extract_release_id([#{<<"release_id">> := ReleaseId} | _]) -> ReleaseId;
extract_release_id([#{release_id := ReleaseId} | _]) -> ReleaseId;
extract_release_id(_) -> undefined.
