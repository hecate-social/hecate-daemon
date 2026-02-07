-module(hecate_mesh_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    %% Check geo-restriction before connecting to mesh
    case check_geo_restriction() of
        ok ->
            start_mesh();
        {error, {geo_restricted, CountryCode}} ->
            io:format("~n~n"),
            io:format("    ╭──────────────────────────────────────────────────╮~n"),
            io:format("    │              ACCESS RESTRICTED                   │~n"),
            io:format("    ├──────────────────────────────────────────────────┤~n"),
            io:format("    │  Hecate is not available in your region (~s).   │~n", [CountryCode]),
            io:format("    │                                                  │~n"),
            io:format("    │  If you believe this is an error, please         │~n"),
            io:format("    │  contact support@hecate.social                   │~n"),
            io:format("    ╰──────────────────────────────────────────────────╯~n"),
            io:format("~n~n"),
            {error, {geo_restricted, CountryCode}}
    end.

stop(_State) ->
    io:format("~n🔌 Disconnecting from Macula mesh...~n~n"),
    ok.

%% @private Check geo-restriction status
check_geo_restriction() ->
    %% Wait for geo_check to be ready (it starts before us in the release)
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
            %% geo_check not available, allow by default
            logger:warning("[hecate_mesh] geo_check not available, allowing connection"),
            ok
    end.

%% @private Wait for geo_check to be available
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

%% @private Start the mesh connection
start_mesh() ->
    %% Get mesh configuration
    BootstrapNodes = application:get_env(hecate_mesh, bootstrap_nodes, ["boot.macula.io:4433"]),
    Realm = application:get_env(hecate_mesh, realm, <<"io.macula">>),
    AgentIdentity = application:get_env(hecate_mesh, agent_identity, <<"mri:agent:io.macula/hecate">>),

    io:format("~n🌐 Connecting to Macula mesh...~n"),
    io:format("   Bootstrap: ~p~n", [BootstrapNodes]),
    io:format("   Realm: ~s~n", [Realm]),
    io:format("   Identity: ~s~n~n", [AgentIdentity]),

    %% Start supervisor (will start mesh client)
    {ok, Pid} = hecate_mesh_sup:start_link(),

    io:format("✅ Mesh client started~n~n"),

    {ok, Pid}.
