%%%-------------------------------------------------------------------
%%% @doc RPC tracking API endpoint.
%%%
%%% Provides endpoint for manually tracking RPC calls for reputation.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_rpc).

-export([init/2]).

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
