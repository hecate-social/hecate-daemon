-module(archive_deployment_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = case Body of
        <<>> -> #{};
        _ -> json:decode(Body)
    end,
    ArchivedBy = maps:get(<<"archived_by">>, Params, undefined),
    Reason = maps:get(<<"reason">>, Params, undefined),
    case archive_deployment_v1:new(#{division_id => DivisionId, archived_by => ArchivedBy, reason => Reason}) of
        {ok, Cmd} ->
            case maybe_archive_deployment:dispatch(Cmd) of
                {ok, Version, Events} ->
                    lists:foreach(fun(E) ->
                        deployment_archived_v1_to_pg:emit(E)
                    end, Events),
                    RespBody = #{
                        division_id => DivisionId,
                        version => Version,
                        events => Events
                    },
                    hecate_api_utils:json_reply(200, RespBody, Req1);
                {error, Reason2} ->
                    hecate_api_utils:json_error(422, Reason2, Req1)
            end;
        {error, Reason3} ->
            hecate_api_utils:json_error(400, Reason3, Req1)
    end.
