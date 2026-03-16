%%% @doc SSE endpoint: GET /api/events
%%%
%%% Long-lived Server-Sent Events connection for streaming domain state
%%% changes to the web frontend (Tauri). One process per connected client.
%%%
%%% On connect: joins `web_connections` pg group, starts heartbeat timer.
%%% On event:   receives {web_event, Type, Data} from hecate_web_events,
%%%             writes `event: {Type}\ndata: {Data}\n\n`.
%%% On disconnect: process dies, pg auto-removes it.
%%%
%%% Pattern: Follows tui_facts_stream_api.erl blocking-init SSE pattern.
%%% @end
-module(web_events_stream_api).

-export([init/2, routes/0]).

-define(SCOPE, pg).
-define(GROUP, web_connections).
-define(HEARTBEAT_MS, 30000).

routes() ->
    [{"/api/events", ?MODULE, []},
     {"/api/events/test", ?MODULE, [test]}].

init(Req0, [test]) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            handle_test_broadcast(Req0);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end;
init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            start_stream(Req0, State);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

%% POST /api/events/test — inject a test event for dev/debugging.
handle_test_broadcast(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    case json:decode(Body) of
        #{<<"event_type">> := EventType, <<"data">> := Data} ->
            EventAtom = binary_to_existing_atom(EventType),
            hecate_web_events:broadcast(EventAtom, Data),
            Resp = json:encode(#{ok => true, event_type => EventType}),
            Req2 = cowboy_req:reply(200, #{<<"content-type">> => <<"application/json">>}, Resp, Req1),
            {ok, Req2, []};
        _ ->
            Resp = json:encode(#{error => <<"expected event_type and data">>}),
            Req2 = cowboy_req:reply(400, #{<<"content-type">> => <<"application/json">>}, Resp, Req1),
            {ok, Req2, []}
    end.

start_stream(Req0, _State) ->
    ensure_pg_scope(),
    pg:join(?SCOPE, ?GROUP, self()),
    logger:info("[web_events_stream] Client connected, pid=~p", [self()]),

    Req1 = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>,
        <<"connection">> => <<"keep-alive">>
    }, Req0),

    cowboy_req:stream_body(<<": connected\n\n">>, nofin, Req1),

    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),

    stream_loop(Req1).

stream_loop(Req) ->
    receive
        {web_event, Type, Data} when is_binary(Type), is_binary(Data) ->
            Payload = <<"event: ", Type/binary, "\ndata: ", Data/binary, "\n\n">>,
            case catch cowboy_req:stream_body(Payload, nofin, Req) of
                ok ->
                    stream_loop(Req);
                _ ->
                    logger:info("[web_events_stream] Client disconnected (write failed)"),
                    {ok, Req, []}
            end;

        heartbeat ->
            case catch cowboy_req:stream_body(<<": heartbeat\n\n">>, nofin, Req) of
                ok ->
                    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),
                    stream_loop(Req);
                _ ->
                    logger:info("[web_events_stream] Client disconnected (heartbeat failed)"),
                    {ok, Req, []}
            end;

        _Other ->
            stream_loop(Req)
    end.

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.
