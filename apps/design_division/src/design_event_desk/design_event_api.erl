-module(design_event_api).
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
    EventName = maps:get(<<"event_name">>, Params, undefined),
    AggregateName = maps:get(<<"aggregate_name">>, Params, undefined),
    PayloadFields = maps:get(<<"payload_fields">>, Params, []),
    Description = maps:get(<<"description">>, Params, undefined),
    case design_event_v1:new(#{
        division_id => DivisionId,
        event_name => EventName,
        aggregate_name => AggregateName,
        payload_fields => PayloadFields,
        description => Description
    }) of
        {ok, Cmd} ->
            case maybe_design_event:dispatch(Cmd) of
                {ok, Version, Events} ->
                    lists:foreach(fun(E) ->
                        event_designed_v1_to_pg:emit(E),
                        event_designed_v1_to_mesh:emit(E)
                    end, Events),
                    RespBody = #{
                        division_id => DivisionId,
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
