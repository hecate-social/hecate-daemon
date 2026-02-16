%%%-------------------------------------------------------------------
%%% @doc Shared socket utilities for Hecate daemon.
%%%
%%% Provides socket path resolution and listener management used by
%%% both hecate_app (early boot) and hecate_api_app (route hot-swap).
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_socket).

-export([get_socket_path/0, ensure_socket_dir/1, start_listener/2]).

%%--------------------------------------------------------------------
%% @doc Resolve the Unix domain socket path.
%%
%% Priority:
%%   1. HECATE_SOCKET_PATH env var (k3s sets this to /run/hecate/daemon.sock)
%%   2. App config socket_path (sys.config)
%%   3. $HOME/.hecate/daemon.sock (user-writable, multi-user safe)
%% @end
%%--------------------------------------------------------------------
-spec get_socket_path() -> string() | undefined.
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

%%--------------------------------------------------------------------
%% @doc Ensure the parent directory for the socket file exists.
%% @end
%%--------------------------------------------------------------------
-spec ensure_socket_dir(string()) -> ok | {error, term()}.
ensure_socket_dir(SocketPath) ->
    Dir = filename:dirname(SocketPath),
    case filelib:ensure_dir(SocketPath) of
        ok ->
            _ = file:change_mode(Dir, 8#755),
            ok;
        {error, Reason} ->
            logger:warning("Cannot create socket directory ~s: ~p", [Dir, Reason]),
            {error, Reason}
    end.

%%--------------------------------------------------------------------
%% @doc Start a cowboy listener on the given Unix socket path.
%%
%% Deletes any stale socket file, ensures the directory exists,
%% then starts a clear (HTTP) listener with the given dispatch.
%% @end
%%--------------------------------------------------------------------
-spec start_listener(string(), cowboy_router:dispatch_rules()) -> ok | {error, term()}.
start_listener(Path, Dispatch) ->
    _ = file:delete(Path),
    case ensure_socket_dir(Path) of
        ok ->
            case cowboy:start_clear(hecate_socket_listener,
                    [{ip, {local, Path}}],
                    #{env => #{dispatch => Dispatch},
                      idle_timeout => infinity}) of
                {ok, _} ->
                    _ = file:change_mode(Path, 8#666),
                    logger:info("Socket listener started: ~s", [Path]),
                    ok;
                {error, Reason} ->
                    logger:warning("Failed to start socket listener: ~p", [Reason]),
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

%% @private Default socket in $HOME/.hecate/ (multi-user safe, no root needed).
default_socket_path() ->
    case os:getenv("HOME") of
        false -> undefined;
        Home -> filename:join([Home, ".hecate", "daemon.sock"])
    end.
