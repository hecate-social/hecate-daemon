-module(hecate_mesh_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case check_geo_restriction() of
        ok ->
            start_mesh();
        {error, {geo_restricted, CountryCode}} ->
            logger:error("[hecate_mesh] Access restricted in region ~s", [CountryCode]),
            {error, {geo_restricted, CountryCode}}
    end.

stop(_State) ->
    logger:info("[hecate_mesh] Stopping mesh service"),
    ok.

check_geo_restriction() ->
    case wait_for_geo_check(10) of
        ok ->
            case geo_check:check_local() of
                allowed ->
                    ok;
                {blocked, CountryCode} ->
                    logger:error("[hecate_mesh] Geo-restricted: ~s", [CountryCode]),
                    {error, {geo_restricted, CountryCode}}
            end;
        {error, not_ready} ->
            logger:warning("[hecate_mesh] geo_check not available, allowing connection"),
            ok
    end.

wait_for_geo_check(0) ->
    {error, not_ready};
wait_for_geo_check(Retries) ->
    case whereis(geo_check_config) of
        undefined ->
            timer:sleep(100),
            wait_for_geo_check(Retries - 1);
        _Pid ->
            ok
    end.

start_mesh() ->
    logger:info("[hecate_mesh] Starting in local mode (activate to connect)"),
    mesh_catch_up:init_position_table(),
    {ok, Pid} = hecate_mesh_sup:start_link(),
    logger:info("[hecate_mesh] Ready (local mode)"),
    maybe_autostart(),
    {ok, Pid}.

%% @doc Headless deployments (beam cluster, nanodes) set
%% HECATE_MESH_AUTOSTART=1 so the mesh activates without an
%% operator-driven `POST /api/mesh/activate'. The activate call runs
%% in a separate process — `application:start' must return promptly,
%% and `hecate_mesh:activate/0' may block while relays are dialled.
maybe_autostart() ->
    case os:getenv("HECATE_MESH_AUTOSTART") of
        Value when Value =:= "1"; Value =:= "true"; Value =:= "yes" ->
            spawn(fun autostart_after_boot/0),
            ok;
        _ ->
            ok
    end.

autostart_after_boot() ->
    %% Give the rest of the supervision tree a beat to settle. The
    %% activate path needs hecate_mesh_client (started by our own
    %% supervisor) plus deferred subscriptions registered by sibling
    %% domain apps.
    timer:sleep(5000),
    logger:info("[hecate_mesh] HECATE_MESH_AUTOSTART set — activating mesh"),
    case hecate_mesh:activate() of
        ok ->
            logger:info("[hecate_mesh] Auto-activated");
        {error, already_activated} ->
            logger:info("[hecate_mesh] Already activated");
        {error, Reason} ->
            logger:warning("[hecate_mesh] Auto-activate failed: ~p", [Reason])
    end.
