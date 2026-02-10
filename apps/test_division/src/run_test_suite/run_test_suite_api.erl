-module(run_test_suite_api).
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
    SuiteName = maps:get(<<"suite_name">>, Params, undefined),
    case SuiteName of
        undefined ->
            hecate_api_utils:json_error(400, <<"suite_name is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"suite_name cannot be empty">>, Req1);
        _ ->
            SuiteType = maps:get(<<"suite_type">>, Params, <<"unit">>),
            TargetModule = maps:get(<<"target_module">>, Params, <<>>),
            case run_test_suite_v1:new(#{
                division_id => DivisionId,
                suite_name => SuiteName,
                suite_type => SuiteType,
                target_module => TargetModule
            }) of
                {ok, Cmd} ->
                    case maybe_run_test_suite:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            SuiteId = extract_suite_id(Events),
                            lists:foreach(fun(E) ->
                                test_suite_run_v1_to_pg:emit(E),
                                test_suite_run_v1_to_mesh:emit(E)
                            end, Events),
                            Body2 = #{
                                division_id => DivisionId,
                                suite_id => SuiteId,
                                suite_name => SuiteName,
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

extract_suite_id([#{<<"suite_id">> := SuiteId} | _]) -> SuiteId;
extract_suite_id([#{suite_id := SuiteId} | _]) -> SuiteId;
extract_suite_id(_) -> undefined.
