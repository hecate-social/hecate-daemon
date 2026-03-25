#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${1:-beam00.lab}"
PORT="${2:-9443}"

rebar3 escriptize 2>/dev/null || true

erl -pa _build/default/lib/*/ebin -noshell -eval "
    application:ensure_all_started(quicer),
    Host = \"${HOST}\",
    Port = ${PORT},
    io:format(\"Testing QUIC to ~s:~p...~n\", [Host, Port]),
    Opts = [{alpn, [\"macula\"]}, {verify, 0}, {peer_unidi_stream_count, 3}, {peer_bidi_stream_count, 3}],
    case quicer:connect(Host, Port, Opts, 5000) of
        {ok, Conn} ->
            io:format(\"SUCCESS: connected ~p~n\", [Conn]),
            quicer:close_connection(Conn);
        {error, Err} ->
            io:format(\"FAILED: ~p~n\", [Err])
    end,
    init:stop().
" 2>&1
