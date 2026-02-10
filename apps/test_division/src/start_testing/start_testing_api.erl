-module(start_testing_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    case start_testing_v1:new(#{division_id => DivisionId}) of
        {ok, Cmd} ->
            case maybe_start_testing:dispatch(Cmd) of
                {ok, Version, Events} ->
                    lists:foreach(fun(E) ->
                        testing_started_v1_to_pg:emit(E),
                        testing_started_v1_to_mesh:emit(E)
                    end, Events),
                    Body = #{
                        division_id => DivisionId,
                        version => Version,
                        events => Events
                    },
                    hecate_api_utils:json_reply(201, Body, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(422, Reason, Req0)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.
