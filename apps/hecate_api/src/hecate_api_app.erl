-module(hecate_api_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    logger:info("[hecate_api] Starting"),
    %% All blocking work (subscriptions, route swap, readiness) is now
    %% handled by hecate_boot_tracker after stores report ready via telemetry.
    hecate_api_sup:start_link().

stop(_State) ->
    %% Socket lifecycle is owned by hecate_app — nothing to do here.
    ok.
