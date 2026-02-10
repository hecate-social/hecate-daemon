-module(record_test_result_api).
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
    SuiteId = maps:get(<<"suite_id">>, Params, undefined),
    TestName = maps:get(<<"test_name">>, Params, undefined),
    case {SuiteId, TestName} of
        {undefined, _} ->
            hecate_api_utils:json_error(400, <<"suite_id is required">>, Req1);
        {_, undefined} ->
            hecate_api_utils:json_error(400, <<"test_name is required">>, Req1);
        {<<>>, _} ->
            hecate_api_utils:json_error(400, <<"suite_id cannot be empty">>, Req1);
        {_, <<>>} ->
            hecate_api_utils:json_error(400, <<"test_name cannot be empty">>, Req1);
        _ ->
            Status = maps:get(<<"status">>, Params, <<"unknown">>),
            Details = maps:get(<<"details">>, Params, undefined),
            case record_test_result_v1:new(#{
                division_id => DivisionId,
                suite_id => SuiteId,
                test_name => TestName,
                status => Status,
                details => Details
            }) of
                {ok, Cmd} ->
                    case maybe_record_test_result:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            ResultId = extract_result_id(Events),
                            lists:foreach(fun(E) ->
                                test_result_recorded_v1_to_pg:emit(E),
                                test_result_recorded_v1_to_mesh:emit(E)
                            end, Events),
                            Body2 = #{
                                division_id => DivisionId,
                                result_id => ResultId,
                                suite_id => SuiteId,
                                test_name => TestName,
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

extract_result_id([#{<<"result_id">> := ResultId} | _]) -> ResultId;
extract_result_id([#{result_id := ResultId} | _]) -> ResultId;
extract_result_id(_) -> undefined.
