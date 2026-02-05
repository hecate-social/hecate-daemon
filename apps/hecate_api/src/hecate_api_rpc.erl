%%%-------------------------------------------------------------------
%%% @doc RPC API endpoints.
%%%
%%% Provides endpoints for:
%%% - Calling procedures (local or mesh)
%%% - Tracking RPC calls for reputation
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_rpc).

-export([init/2]).

%% POST /api/rpc/call - Call a procedure
init(Req0, [call]) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),

    case json:decode(Body) of
        #{<<"procedure">> := Procedure} = Payload ->
            Args = maps:get(<<"args">>, Payload, null),
            StartTime = erlang:monotonic_time(millisecond),

            Result = handle_rpc_call(Procedure, Args),

            Duration = erlang:monotonic_time(millisecond) - StartTime,

            case Result of
                {ok, ResultData} ->
                    Response = #{
                        ok => true,
                        result => #{
                            result => ResultData,
                            duration => format_duration(Duration)
                        }
                    },
                    reply_json(200, Response, Req1);
                {error, Reason} ->
                    Response = #{
                        ok => true,
                        result => #{
                            result => null,
                            error => format_error(Reason),
                            duration => format_duration(Duration)
                        }
                    },
                    reply_json(200, Response, Req1)
            end;
        _ ->
            error_response(Req1, 400, <<"procedure field is required">>)
    end;

%% POST /rpc/track - Manually track an RPC call for reputation
init(Req0, [track]) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),

    case json:decode(Body) of
        #{
            <<"caller_identity">> := Caller,
            <<"callee_identity">> := Callee,
            <<"procedure">> := Procedure,
            <<"call_duration_ms">> := Duration,
            <<"success">> := Success
        } = Payload ->
            ErrorReason = maps:get(<<"error_reason">>, Payload, undefined),
            Metadata = maps:get(<<"metadata">>, Payload, #{}),
            Timestamp = erlang:system_time(millisecond),

            Cmd = track_rpc_call_v1:new(
                Caller,
                Callee,
                Procedure,
                Duration,
                Success,
                ErrorReason,
                Metadata,
                Timestamp
            ),

            case maybe_track_rpc_call:dispatch(Cmd) of
                {ok, Version, Events} ->
                    Response = #{
                        ok => true,
                        version => Version,
                        events => Events
                    },
                    reply_json(201, Response, Req1);
                {error, Reason} ->
                    error_response(Req1, 400, Reason)
            end;
        _ ->
            error_response(Req1, 400, invalid_request_body)
    end.

%% Internal functions

%% Handle RPC calls - internal procedures or mesh calls
handle_rpc_call(<<"mri:proc:hecate:pubsub.publish">>, Args) ->
    %% Internal pubsub.publish procedure
    handle_pubsub_publish(Args);
handle_rpc_call(<<"mri:proc:hecate:", _Rest/binary>> = Procedure, _Args) ->
    %% Other internal hecate procedures - not implemented yet
    {error, iolist_to_binary([<<"procedure not implemented: ">>, Procedure])};
handle_rpc_call(Procedure, Args) ->
    %% External mesh RPC call
    %% For now, return not implemented - mesh RPC will be added later
    %% TODO: Integrate with hecate_mesh for actual mesh RPC calls
    logger:info("RPC call to ~s with args ~p (mesh RPC not yet implemented)",
                [Procedure, Args]),
    {error, <<"mesh RPC calls not yet implemented">>}.

%% Handle pubsub.publish - publish a message to a topic
handle_pubsub_publish(null) ->
    {error, <<"args required: topic and payload">>};
handle_pubsub_publish(Args) when is_map(Args) ->
    Topic = maps:get(<<"topic">>, Args, undefined),
    Payload = maps:get(<<"payload">>, Args, undefined),

    case {Topic, Payload} of
        {undefined, _} ->
            {error, <<"topic is required">>};
        {_, undefined} ->
            {error, <<"payload is required">>};
        {T, P} when is_binary(T) ->
            %% TODO: Actually publish to mesh when mesh pubsub is integrated
            %% For now, log and return success
            logger:info("Publishing to topic ~s: ~p", [T, P]),
            {ok, #{published => true, topic => T}};
        _ ->
            {error, <<"topic must be a string">>}
    end;
handle_pubsub_publish(_) ->
    {error, <<"args must be an object with topic and payload">>}.

%% Format duration for response
format_duration(Ms) when is_integer(Ms) ->
    iolist_to_binary(io_lib:format("~Bms", [Ms])).

reply_json(Status, Data, Req0) ->
    Body = json:encode(Data),
    Req = cowboy_req:reply(Status, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, []}.

error_response(Req, StatusCode, Reason) ->
    Response = #{
        ok => false,
        error => format_error(Reason)
    },
    reply_json(StatusCode, Response, Req).

format_error(Reason) when is_atom(Reason) ->
    atom_to_binary(Reason);
format_error(Reason) when is_binary(Reason) ->
    Reason;
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
