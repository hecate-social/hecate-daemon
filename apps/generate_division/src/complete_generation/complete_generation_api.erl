-module(complete_generation_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    case complete_generation_v1:new(#{division_id => DivisionId}) of
        {ok, Cmd} ->
            case maybe_complete_generation:dispatch(Cmd) of
                {ok, Version, Events} ->
                    lists:foreach(fun(E) ->
                        generation_completed_v1_to_pg:emit(E)
                    end, Events),
                    Body = #{
                        division_id => DivisionId,
                        version => Version,
                        events => Events
                    },
                    hecate_api_utils:json_reply(200, Body, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(422, Reason, Req0)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.
