-module(generate_test_api).
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
    TestName = maps:get(<<"test_name">>, Params, undefined),
    TestType = maps:get(<<"test_type">>, Params, <<"unit">>),
    ModuleName = maps:get(<<"module_name">>, Params, <<>>),
    FilePath = maps:get(<<"file_path">>, Params, <<>>),
    Content = maps:get(<<"content">>, Params, <<>>),
    Description = maps:get(<<"description">>, Params, undefined),
    GeneratedBy = maps:get(<<"generated_by">>, Params, undefined),
    case generate_test_v1:new(#{
        division_id => DivisionId,
        test_name => TestName,
        test_type => TestType,
        module_name => ModuleName,
        file_path => FilePath,
        content => Content,
        description => Description,
        generated_by => GeneratedBy
    }) of
        {ok, Cmd} ->
            case maybe_generate_test:dispatch(Cmd) of
                {ok, Version, Events} ->
                    TestId = extract_test_id(Events),
                    lists:foreach(fun(E) ->
                        test_generated_v1_to_pg:emit(E),
                        test_generated_v1_to_mesh:emit(E)
                    end, Events),
                    RespBody = #{
                        division_id => DivisionId,
                        test_id => TestId,
                        test_name => TestName,
                        test_type => TestType,
                        version => Version,
                        events => Events
                    },
                    hecate_api_utils:json_reply(201, RespBody, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(422, Reason, Req1)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req1)
    end.

extract_test_id([#{<<"test_id">> := TestId} | _]) -> TestId;
extract_test_id([#{test_id := TestId} | _]) -> TestId;
extract_test_id(_) -> undefined.
