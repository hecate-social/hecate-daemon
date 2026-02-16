-module(call_rpc_api).
-export([init/2, routes/0]).

routes() -> [{"/api/rpc/call", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"procedure">> := Procedure} = Payload, Req1} ->
            Args = maps:get(<<"args">>, Payload, null),
            StartTime = erlang:monotonic_time(millisecond),
            Result = handle_rpc_call(Procedure, Args),
            Duration = erlang:monotonic_time(millisecond) - StartTime,
            case Result of
                {ok, ResultData} ->
                    hecate_api_utils:json_ok(#{
                        result => #{
                            result => ResultData,
                            duration => format_duration(Duration)
                        }
                    }, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_ok(#{
                        result => #{
                            result => null,
                            error => hecate_api_utils:format_error(Reason),
                            duration => format_duration(Duration)
                        }
                    }, Req1)
            end;
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"procedure field is required">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

handle_rpc_call(<<"mri:proc:hecate:pubsub.publish">>, Args) ->
    handle_pubsub_publish(Args);
handle_rpc_call(<<"mri:proc:hecate:", _Rest/binary>> = Procedure, _Args) ->
    {error, iolist_to_binary([<<"procedure not implemented: ">>, Procedure])};
handle_rpc_call(Procedure, Args) ->
    logger:info("RPC call to ~s with args ~p (mesh RPC not yet implemented)",
                [Procedure, Args]),
    {error, <<"mesh RPC calls not yet implemented">>}.

handle_pubsub_publish(null) ->
    {error, <<"args required: topic and payload">>};
handle_pubsub_publish(Args) when is_map(Args) ->
    Topic = maps:get(<<"topic">>, Args, undefined),
    Payload = maps:get(<<"payload">>, Args, undefined),
    case {Topic, Payload} of
        {undefined, _} -> {error, <<"topic is required">>};
        {_, undefined} -> {error, <<"payload is required">>};
        {T, P} when is_binary(T) ->
            logger:info("Publishing to topic ~s: ~p", [T, P]),
            {ok, #{published => true, topic => T}};
        _ -> {error, <<"topic must be a string">>}
    end;
handle_pubsub_publish(_) ->
    {error, <<"args must be an object with topic and payload">>}.

format_duration(Ms) when is_integer(Ms) ->
    iolist_to_binary(io_lib:format("~Bms", [Ms])).
