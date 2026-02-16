%%% @doc SSE endpoint: GET /api/arcade/snake-duel/matches/:match_id/stream
%%%
%%% Long-lived Server-Sent Events connection for streaming live duel
%%% state to connected clients. Joins the duel's pg group and forwards
%%% each game state update as an SSE data frame.
%%% @end
-module(stream_duel_api).

-export([init/2, routes/0]).

-define(HEARTBEAT_MS, 15000).

routes() -> [{"/api/arcade/snake-duel/matches/:match_id/stream", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            MatchId = cowboy_req:binding(match_id, Req0),
            start_stream(MatchId, Req0, State);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

start_stream(MatchId, Req0, _State) ->
    %% Join the duel's pg group
    ensure_pg(),
    pg:join(pg, {snake_duel, MatchId}, self()),

    %% Start SSE stream
    Req1 = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>,
        <<"connection">> => <<"keep-alive">>,
        <<"access-control-allow-origin">> => <<"*">>
    }, Req0),

    %% Send initial comment to confirm connection
    cowboy_req:stream_body(<<": connected\n\n">>, nofin, Req1),

    %% If duel proc exists, request current state
    case persistent_term:get({snake_duel, MatchId}, undefined) of
        undefined -> ok;
        Pid when is_pid(Pid) ->
            case is_process_alive(Pid) of
                true ->
                    case duel_proc:get_state(Pid) of
                        {ok, StateMap} ->
                            send_state(Req1, StateMap);
                        _ -> ok
                    end;
                false -> ok
            end
    end,

    %% Start heartbeat timer
    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),

    %% Enter receive loop
    stream_loop(Req1).

stream_loop(Req) ->
    receive
        {snake_duel_state, StateMap} ->
            case send_state(Req, StateMap) of
                ok ->
                    %% If duel finished, send one last frame and close
                    case maps:get(status, StateMap, undefined) of
                        finished ->
                            {ok, Req, []};
                        _ ->
                            stream_loop(Req)
                    end;
                error ->
                    {ok, Req, []}
            end;

        heartbeat ->
            case catch cowboy_req:stream_body(<<": heartbeat\n\n">>, nofin, Req) of
                ok ->
                    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),
                    stream_loop(Req);
                _ ->
                    {ok, Req, []}
            end;

        _Other ->
            stream_loop(Req)
    end.

send_state(Req, StateMap) ->
    Data = iolist_to_binary(json:encode(StateMap)),
    case catch cowboy_req:stream_body(
        <<"data: ", Data/binary, "\n\n">>, nofin, Req
    ) of
        ok -> ok;
        _ -> error
    end.

ensure_pg() ->
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.
