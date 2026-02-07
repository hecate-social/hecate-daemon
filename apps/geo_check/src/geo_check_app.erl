%%% @doc geo_check OTP application
%%% Geographic restriction service - validates IP addresses against configured
%%% country allowlist/blocklist.
-module(geo_check_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case application:get_env(geo_check, enabled, true) of
        true ->
            logger:info("[geo_check] Starting geographic restriction service"),
            geo_check_sup:start_link();
        false ->
            logger:info("[geo_check] Geographic restriction service disabled"),
            {ok, spawn_link(fun() -> receive stop -> ok end end)}
    end.

stop(_State) ->
    ok.
