#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

HOST="${1:-beam00.lab}"
PORT="${2:-9443}"

erl -pa _build/default/lib/*/ebin -noshell -eval "
    application:ensure_all_started(quicer),
    Host = \"${HOST}\",
    Port = ${PORT},

    %% Test 1: minimal opts (what works)
    io:format(\"Test 1: minimal opts to ~s:~p...~n\", [Host, Port]),
    R1 = quicer:connect(Host, Port, [{alpn, [\"macula\"]}, {verify, 0}], 5000),
    io:format(\"  Result: ~p~n\", [R1]),
    case R1 of {ok, C1} -> quicer:close_connection(C1); _ -> ok end,

    %% Test 2: with handshake_idle_timeout (what macula uses)
    io:format(\"Test 2: with handshake_idle_timeout 30s...~n\"),
    R2 = quicer:connect(Host, Port, [
        {alpn, [\"macula\"]},
        {verify, 0},
        {idle_timeout_ms, 60000},
        {keep_alive_interval_ms, 20000},
        {handshake_idle_timeout_ms, 30000}
    ], 5000),
    io:format(\"  Result: ~p~n\", [R2]),
    case R2 of {ok, C2} -> quicer:close_connection(C2); _ -> ok end,

    %% Test 3: with verify=none (atom, not 0)
    io:format(\"Test 3: verify=none (atom)...~n\"),
    R3 = quicer:connect(Host, Port, [
        {alpn, [\"macula\"]},
        {verify, none},
        {idle_timeout_ms, 60000},
        {keep_alive_interval_ms, 20000},
        {handshake_idle_timeout_ms, 30000}
    ], 5000),
    io:format(\"  Result: ~p~n\", [R3]),
    case R3 of {ok, C3} -> quicer:close_connection(C3); _ -> ok end,

    init:stop().
" 2>&1
