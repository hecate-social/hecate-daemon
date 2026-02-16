-module(hecate_api_app).
-behaviour(application).

-export([start/2, stop/1]).

-dialyzer({nowarn_function, [start/2, auto_register_default_connector/0]}).

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

    %% Auto-register default TUI connector after sup is up
    auto_register_default_connector(),

    Result.

stop(_State) ->
    %% Socket lifecycle is owned by hecate_app — nothing to do here.
    ok.

%% @private Auto-register the default TUI connector on first boot.
%% Dispatches a register_connector command if configured.
auto_register_default_connector() ->
    case application:get_env(guide_node_lifecycle, default_connector) of
        {ok, #{id := ConnId, name := Name, allowed_routes := AllowedRoutes}} ->
            CmdParams = #{
                connector_id => ConnId,
                name => Name,
                allowed_routes => AllowedRoutes,
                metadata => #{auto_registered => true}
            },
            case register_connector_v1:new(CmdParams) of
                {ok, Cmd} ->
                    case maybe_register_connector:dispatch(Cmd) of
                        {ok, _Version, _Events} ->
                            logger:info("Auto-registered default connector: ~s", [ConnId]);
                        {error, connector_already_registered} ->
                            logger:info("Default connector ~s already registered", [ConnId]);
                        {error, Reason} ->
                            logger:warning("Failed to auto-register connector ~s: ~p",
                                           [ConnId, Reason])
                    end;
                {error, Reason} ->
                    logger:warning("Invalid default connector config: ~p", [Reason])
            end;
        _ ->
            ok
    end.
