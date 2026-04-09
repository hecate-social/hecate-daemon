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
    mesh_catch_up:init_position_table(),
    {ok, Pid} = hecate_mesh_sup:start_link(),
    logger:info("[hecate_mesh] Mesh client started"),
    %% Register dist relay async — don't block app startup on relay connection.
    %% The advertise call does gen_server:call to the mesh client which may not
    %% be connected yet (race with relay handshake).
    spawn(fun() -> register_dist_relay_with_retry(5) end),
    {ok, Pid}.

register_dist_relay_with_retry(0) ->
    logger:warning("[hecate_mesh] Distribution relay registration failed after retries");
register_dist_relay_with_retry(Retries) ->
    timer:sleep(2000),
    case hecate_mesh_client:get_client() of
        {ok, Client} ->
            macula_dist_relay:register_mesh_client(Client),
            case catch macula_dist_relay:advertise_dist_accept() of
                ok ->
                    logger:info("[hecate_mesh] Distribution relay registered");
                {'EXIT', {timeout, _}} ->
                    logger:warning("[hecate_mesh] Advertise timed out, retrying (~p left)",
                                   [Retries - 1]),
                    register_dist_relay_with_retry(Retries - 1);
                Other ->
                    logger:warning("[hecate_mesh] Advertise failed: ~p, retrying (~p left)",
                                   [Other, Retries - 1]),
                    register_dist_relay_with_retry(Retries - 1)
            end;
        _ ->
            logger:info("[hecate_mesh] No mesh client yet, retrying (~p left)", [Retries - 1]),
            register_dist_relay_with_retry(Retries - 1)
    end.
