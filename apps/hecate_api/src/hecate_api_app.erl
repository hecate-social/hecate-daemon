-module(hecate_api_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    logger:info("[hecate_api] Starting hecate_api application"),

    %% Start store subscriptions NOW — after all domain apps have started.
    %% This guarantees projections are registered with the type registry
    %% before the $all subscription replays historical events.
    hecate_app:start_store_subscriptions(),

    %% Compile full routes and hot-swap onto the already-running listener.
    %% The socket was started early by hecate_app with startup-health-only
    %% dispatch. Now we replace it with the full route table.
    Dispatch = hecate_api_routes:compile(),
    cowboy:set_env(hecate_socket_listener, dispatch, Dispatch),
    logger:info("[hecate_api] Full routes loaded — awaiting projection replay"),

    %% Don't set `running` yet — store subscriptions deliver events
    %% asynchronously. A background watcher monitors ETS tables and
    %% sets `running` once projections have replayed all historical events.
    %% Until then, /health returns ready:false and the frontend shows
    %% a loading overlay (not the onboarding overlay).
    hecate_readiness:await_projections(),

    Result = hecate_api_sup:start_link(),
    logger:info("[hecate_api] Supervisor started: ~p", [Result]),

    Result.

stop(_State) ->
    %% Socket lifecycle is owned by hecate_app — nothing to do here.
    ok.
