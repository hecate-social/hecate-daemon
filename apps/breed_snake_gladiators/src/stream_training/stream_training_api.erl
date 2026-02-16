%%% @doc SSE endpoint: GET /api/arcade/gladiators/stables/:stable_id/stream
%%%
%%% Long-lived Server-Sent Events connection for streaming live training
%%% progress to connected clients. Joins the training's pg group and
%%% forwards each progress update as an SSE data frame.
%%% @end
-module(stream_training_api).

-export([init/2, routes/0]).

-define(HEARTBEAT_MS, 15000).

routes() -> [{"/api/arcade/gladiators/stables/:stable_id/stream", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            StableId = cowboy_req:binding(stable_id, Req0),
            start_stream(StableId, Req0, State);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

start_stream(StableId, Req0, _State) ->
    %% Join the training's pg group
    ensure_pg(),
    pg:join(pg, {gladiator_training, StableId}, self()),

    %% Start SSE stream
    Req1 = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>,
        <<"connection">> => <<"keep-alive">>,
        <<"access-control-allow-origin">> => <<"*">>
    }, Req0),

    %% Send initial comment to confirm connection
    cowboy_req:stream_body(<<": connected\n\n">>, nofin, Req1),

    %% If training proc exists, request current state
    case persistent_term:get({gladiator_training, StableId}, undefined) of
        undefined -> ok;
        Pid when is_pid(Pid) ->
            case is_process_alive(Pid) of
                true ->
                    case training_proc:get_status(Pid) of
                        {ok, StatusMap} ->
                            send_state(Req1, StatusMap);
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
        {gladiator_training_state, StatusMap} ->
            case send_state(Req, StatusMap) of
                ok ->
                    %% If training finished/halted, send one last frame and close
                    case maps:get(status, StatusMap, undefined) of
                        <<"completed">> ->
                            {ok, Req, []};
                        <<"halted">> ->
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

send_state(Req, StatusMap) ->
    Data = iolist_to_binary(json:encode(StatusMap)),
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
