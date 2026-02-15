%%% @doc API handler: POST /api/arcade/snake-duel/matches
%%% Starts a new snake duel.
-module(start_duel_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_start(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_start(Params, Req) ->
    AF1 = to_integer(hecate_api_utils:get_field(af1, Params), 50),
    AF2 = to_integer(hecate_api_utils:get_field(af2, Params), 50),
    TickMs = to_integer(hecate_api_utils:get_field(tick_ms, Params), 100),

    CmdParams = #{af1 => AF1, af2 => AF2, tick_ms => TickMs},
    case start_duel_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_start_duel:dispatch(Cmd) of
                {ok, MatchId, _Pid} ->
                    hecate_api_utils:json_ok(201, #{
                        match_id => MatchId,
                        af1 => AF1,
                        af2 => AF2,
                        tick_ms => TickMs,
                        status => <<"countdown">>
                    }, Req);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

to_integer(V, _Default) when is_integer(V) -> V;
to_integer(V, _Default) when is_float(V) -> round(V);
to_integer(V, _Default) when is_binary(V) ->
    try binary_to_integer(V) catch _:_ -> 0 end;
to_integer(_, Default) -> Default.
