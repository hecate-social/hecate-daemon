-module(generate_module_api).
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
    ModuleName = maps:get(<<"module_name">>, Params, undefined),
    case ModuleName of
        undefined ->
            hecate_api_utils:json_error(400, <<"module_name is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"module_name cannot be empty">>, Req1);
        _ ->
            ModuleType = maps:get(<<"module_type">>, Params, <<"command">>),
            FilePath = maps:get(<<"file_path">>, Params, <<>>),
            Content = maps:get(<<"content">>, Params, <<>>),
            Description = maps:get(<<"description">>, Params, undefined),
            GeneratedBy = maps:get(<<"generated_by">>, Params, undefined),
            case generate_module_v1:new(#{
                division_id => DivisionId,
                module_name => ModuleName,
                module_type => ModuleType,
                file_path => FilePath,
                content => Content,
                description => Description,
                generated_by => GeneratedBy
            }) of
                {ok, Cmd} ->
                    case maybe_generate_module:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            ModuleId = extract_module_id(Events),
                            lists:foreach(fun(E) ->
                                module_generated_v1_to_pg:emit(E),
                                module_generated_v1_to_mesh:emit(E)
                            end, Events),
                            Body2 = #{
                                division_id => DivisionId,
                                module_id => ModuleId,
                                module_name => ModuleName,
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

extract_module_id([#{<<"module_id">> := ModuleId} | _]) -> ModuleId;
extract_module_id([#{module_id := ModuleId} | _]) -> ModuleId;
extract_module_id(_) -> undefined.
