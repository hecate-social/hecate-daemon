%%% @doc SSE endpoint: GET /api/facts/stream
%%%
%%% Long-lived Server-Sent Events connection for streaming domain facts
%%% to connected TUI clients. One process per connected TUI.
%%%
%%% On connect: joins `tui_connections` pg group, starts heartbeat timer.
%%% On fact:    receives {tui_fact, Data} from _to_tui emitters, writes SSE data line.
%%% On disconnect: process dies, pg auto-removes it.
%%%
%%% Pattern: Follows chat_to_llm_api.erl blocking-init SSE pattern.
%%% @end
-module(tui_facts_stream_api).

-export([init/2]).

-define(SCOPE, pg).
-define(GROUP, tui_connections).
-define(HEARTBEAT_MS, 30000).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            start_stream(Req0, State);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

start_stream(Req0, _State) ->
    %% Ensure pg scope exists and join tui_connections group
    ensure_pg_scope(),
    pg:join(?SCOPE, ?GROUP, self()),
    logger:info("[tui_facts_stream] Client connected, pid=~p", [self()]),

    %% Start SSE stream
    Req1 = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>,
        <<"connection">> => <<"keep-alive">>
    }, Req0),

    %% Send initial comment to confirm connection
    cowboy_req:stream_body(<<": connected\n\n">>, nofin, Req1),

    %% Start heartbeat timer
    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),

    %% Enter receive loop (blocks until client disconnects)
    stream_loop(Req1).

stream_loop(Req) ->
    receive
        {tui_fact, Data} when is_binary(Data) ->
            case catch cowboy_req:stream_body(
                <<"data: ", Data/binary, "\n\n">>, nofin, Req
            ) of
                ok ->
                    stream_loop(Req);
                _ ->
                    %% Client disconnected
                    logger:info("[tui_facts_stream] Client disconnected (write failed)"),
                    {ok, Req, []}
            end;

        heartbeat ->
            case catch cowboy_req:stream_body(
                <<": heartbeat\n\n">>, nofin, Req
            ) of
                ok ->
                    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),
                    stream_loop(Req);
                _ ->
                    %% Client disconnected
                    logger:info("[tui_facts_stream] Client disconnected (heartbeat failed)"),
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
