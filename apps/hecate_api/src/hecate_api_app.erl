-module(hecate_api_app).
-behaviour(application).

-export([start/2, stop/1]).

-dialyzer({nowarn_function, [start/2, auto_register_default_connector/0]}).

start(_StartType, _StartArgs) ->
    %% Get HTTP configuration
    Port = application:get_env(hecate_api, http_port, 4444),
    TcpEnabled = application:get_env(manage_connectors, tcp_listener, true),

    %% Compile shared routes
    Dispatch = hecate_api_routes:compile(),

    %% Start TCP listener (opt-in, enabled by default during transition)
    case TcpEnabled of
        true ->
            {ok, _} = cowboy:start_clear(hecate_http_listener,
                [{port, Port}],
                #{env => #{dispatch => Dispatch}}
            ),
            logger:info("Hecate API listening on http://127.0.0.1:~p", [Port]);
        false ->
            logger:info("Hecate TCP listener disabled (Unix sockets only)")
    end,

    Result = hecate_api_sup:start_link(),

    %% Auto-register default TUI connector after sup is up
    auto_register_default_connector(),

    Result.

stop(_State) ->
    cowboy:stop_listener(hecate_http_listener),
    ok.

%% @private Auto-register the default TUI connector on first boot.
%% Dispatches a register_connector command if configured.
auto_register_default_connector() ->
    case application:get_env(manage_connectors, default_connector) of
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
