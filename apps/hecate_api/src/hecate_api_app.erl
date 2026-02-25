-module(hecate_api_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    logger:info("[hecate_api] Starting hecate_api application"),

    %% Compile full routes and hot-swap onto the already-running listener.
    %% The socket was started early by hecate_app with startup-health-only
    %% dispatch. Now we replace it with the full route table.
    Dispatch = hecate_api_routes:compile(),
    cowboy:set_env(hecate_socket_listener, dispatch, Dispatch),
    logger:info("[hecate_api] Full routes loaded — daemon ready"),

    %% Mark daemon as fully operational
    hecate_lifecycle:set_state(running),

    Result = hecate_api_sup:start_link(),
    logger:info("[hecate_api] Supervisor started: ~p", [Result]),

    Result.

stop(_State) ->
    %% Socket lifecycle is owned by hecate_app — nothing to do here.
    ok.
