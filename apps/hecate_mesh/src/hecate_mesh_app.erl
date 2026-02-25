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
    logger:info("[hecate_mesh] Disconnecting from Macula mesh"),
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
    logger:info("[hecate_mesh] Connecting to Macula mesh"),
    {ok, Pid} = hecate_mesh_sup:start_link(),
    logger:info("[hecate_mesh] Mesh client started"),
    {ok, Pid}.
