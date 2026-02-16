-module(hecate_api_app).
-behaviour(application).

-export([start/2, stop/1]).

-dialyzer({nowarn_function, [start/2, auto_register_default_connector/0,
                             start_socket_listener/2, ensure_socket_dir/1,
                             get_socket_path/0]}).

start(_StartType, _StartArgs) ->
    logger:info("[hecate_api] Starting hecate_api application"),

    %% Socket path: check OS env first (k3s deployment), then app config
    SocketPath = get_socket_path(),
    logger:info("[hecate_api] Socket path resolved to: ~p", [SocketPath]),

    %% Compile shared routes
    Dispatch = hecate_api_routes:compile(),
    logger:info("[hecate_api] Routes compiled successfully"),

    %% TCP listener removed for security - Unix socket only
    %% See: hecate-hardening-plan.md Task 1

    %% Start Unix socket listener if configured
    case SocketPath of
        undefined ->
            logger:info("[hecate_api] Socket path is undefined, skipping listener");
        {ok, Path} when is_list(Path) ->
            start_socket_listener(Path, Dispatch);
        Path when is_list(Path) ->
            start_socket_listener(Path, Dispatch);
        Path when is_binary(Path) ->
            start_socket_listener(binary_to_list(Path), Dispatch)
    end,

    Result = hecate_api_sup:start_link(),
    logger:info("[hecate_api] Supervisor started: ~p", [Result]),

    %% Auto-register default TUI connector after sup is up
    auto_register_default_connector(),

    Result.

stop(_State) ->
    cowboy:stop_listener(hecate_socket_listener),
    %% Clean up socket file
    case application:get_env(hecate_api, socket_path) of
        {ok, Path} when is_list(Path) ->
            file:delete(Path);
        {ok, Path} when is_binary(Path) ->
            file:delete(binary_to_list(Path));
        _ ->
            ok
    end,
    ok.

%% @private Start Unix socket listener for local TUI communication.
%% Uses Ranch's support for Unix domain sockets via {local, Path}.
start_socket_listener(Path, Dispatch) ->
    %% Ensure socket directory exists
    ok = ensure_socket_dir(Path),

    %% Remove stale socket file if exists
    _ = file:delete(Path),

    %% Start cowboy listener on Unix socket
    %% Ranch supports Unix sockets via {ip, {local, Path}}
    case cowboy:start_clear(hecate_socket_listener,
            [{ip, {local, Path}}],
            #{env => #{dispatch => Dispatch},
              %% SSE streams are long-lived; default idle_timeout (60s)
              %% kills them because the client sends no data after the
              %% initial request.  Setting infinity lets heartbeats
              %% keep the connection alive instead.
              idle_timeout => infinity}) of
        {ok, _} ->
            %% Set socket permissions for local access
            %% Note: 0666 allows any local user; use 0660 + hecate group for stricter security
            _ = file:change_mode(Path, 8#666),
            logger:info("Hecate API listening on Unix socket: ~s", [Path]);
        {error, Reason} ->
            logger:warning("Failed to start Unix socket listener: ~p", [Reason])
    end.

%% @private Get socket path from OS env or $HOME/.hecate/.
%% Priority:
%%   1. HECATE_SOCKET_PATH env var (k3s sets this to /run/hecate/daemon.sock)
%%   2. App config socket_path (sys.config)
%%   3. $HOME/.hecate/daemon.sock (user-writable, multi-user safe)
get_socket_path() ->
    case os:getenv("HECATE_SOCKET_PATH") of
        false ->
            case application:get_env(hecate_api, socket_path) of
                {ok, Path} when is_list(Path), Path =/= "" -> Path;
                {ok, Path} when is_binary(Path), Path =/= <<>> -> binary_to_list(Path);
                _ -> default_socket_path()
            end;
        "" ->
            undefined;
        EnvPath ->
            EnvPath
    end.

%% @private Default socket in $HOME/.hecate/ (multi-user safe, no root needed).
default_socket_path() ->
    case os:getenv("HOME") of
        false -> undefined;
        Home -> filename:join([Home, ".hecate", "daemon.sock"])
    end.

%% @private Ensure the socket directory exists with proper permissions.
ensure_socket_dir(SocketPath) ->
    Dir = filename:dirname(SocketPath),
    case filelib:ensure_dir(SocketPath) of
        ok ->
            %% Set directory permissions to allow local access
            _ = file:change_mode(Dir, 8#755),
            ok;
        {error, Reason} ->
            logger:warning("Cannot create socket directory ~s: ~p", [Dir, Reason]),
            {error, Reason}
    end.

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
