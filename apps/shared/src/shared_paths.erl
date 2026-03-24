%%% @doc Shared path utilities for hecate-daemon.
%%%
%%% Provides purpose-specific path functions for the namespaced
%%% directory layout under ~/.hecate/hecate-daemon/:
%%%
%%%   reckon-db/    - ReckonDB (Khepri/Ra) event store data
%%%   sockets/      - Unix domain sockets
%%%   run/          - PID and state files
%%%   connectors/   - Connector socket files
%%%
%%% The base directory is configured via {hecate, [{data_dir, Path}]}.
%%% Default: ~/.hecate/hecate-daemon
-module(shared_paths).

-export([
    base_dir/0,
    hecate_home/0,
    hecate_home_rel/0,
    base_dir_rel/0,
    config_dir/0,
    config_path/1,
    reckon_dir/0,
    reckon_path/1,
    socket_dir/0,
    socket_path/1,
    run_dir/0,
    run_path/1,
    connectors_dir/0,
    gitops_apps_dir/0,
    ensure_layout/0
]).

%% @doc Returns the base directory for this daemon instance.
%% Resolution order:
%%   1. HECATE_HOME env var (e.g., /fast/.hecate) → appends /hecate-daemon
%%   2. {hecate, [{data_dir, Path}]} app env
%%   3. Default: ~/.hecate/hecate-daemon
-spec base_dir() -> file:filename().
base_dir() ->
    case os:getenv("HECATE_HOME") of
        false ->
            case application:get_env(hecate, data_dir) of
                {ok, Dir} -> expand_path(Dir);
                undefined -> expand_path("~/.hecate/hecate-daemon")
            end;
        HecateHome ->
            filename:join(HecateHome, "hecate-daemon")
    end.

%% @doc Returns the hecate home directory (~/.hecate or $HECATE_HOME).
-spec hecate_home() -> file:filename().
hecate_home() ->
    case os:getenv("HECATE_HOME") of
        false -> filename:dirname(base_dir());
        HecateHome -> HecateHome
    end.

%% @doc Returns the hecate home path relative to $HOME.
%% Used in systemd .container files where %h expands to $HOME.
-spec hecate_home_rel() -> string().
hecate_home_rel() ->
    Home = os:getenv("HOME"),
    Full = hecate_home(),
    case lists:prefix(Home, Full) of
        true ->
            %% Strip $HOME prefix and leading slash
            Rel = lists:nthtail(length(Home), Full),
            case Rel of
                "/" ++ Rest -> Rest;
                _ -> Rel
            end;
        false ->
            Full
    end.

%% @doc Returns the base directory path relative to $HOME.
%% Used in systemd .container files where %h expands to $HOME.
-spec base_dir_rel() -> string().
base_dir_rel() ->
    Home = os:getenv("HOME"),
    Full = base_dir(),
    case lists:prefix(Home, Full) of
        true ->
            Rel = lists:nthtail(length(Home), Full),
            case Rel of
                "/" ++ Rest -> Rest;
                _ -> Rel
            end;
        false ->
            Full
    end.

%% @doc Returns the shared config directory (~/.hecate/config).
-spec config_dir() -> file:filename().
config_dir() ->
    filename:join(hecate_home(), "config").

%% @doc Returns the full path for a named config file.
-spec config_path(string() | binary()) -> file:filename().
config_path(Name) ->
    filename:join(config_dir(), Name).

%% @doc Returns the directory for ReckonDB event store data.
-spec reckon_dir() -> file:filename().
reckon_dir() ->
    filename:join(base_dir(), "reckon-db").

%% @doc Returns the full path for a ReckonDB store.
-spec reckon_path(string() | binary()) -> file:filename().
reckon_path(Name) ->
    filename:join(reckon_dir(), Name).

%% @doc Returns the directory for Unix domain sockets.
-spec socket_dir() -> file:filename().
socket_dir() ->
    filename:join(base_dir(), "sockets").

%% @doc Returns the full path for a named socket file.
-spec socket_path(string() | binary()) -> file:filename().
socket_path(Name) ->
    filename:join(socket_dir(), Name).

%% @doc Returns the directory for runtime files (PID, state).
-spec run_dir() -> file:filename().
run_dir() ->
    filename:join(base_dir(), "run").

%% @doc Returns the full path for a runtime file.
-spec run_path(string() | binary()) -> file:filename().
run_path(Name) ->
    filename:join(run_dir(), Name).

%% @doc Returns the directory for connector socket files.
-spec connectors_dir() -> file:filename().
connectors_dir() ->
    filename:join(base_dir(), "connectors").

%% @doc Returns the gitops apps directory (~/.hecate/gitops/apps).
-spec gitops_apps_dir() -> file:filename().
gitops_apps_dir() ->
    filename:join([hecate_home(), "gitops", "apps"]).

%% @doc Creates all subdirectories under base_dir().
%% Idempotent - safe to call multiple times.
-spec ensure_layout() -> ok.
ensure_layout() ->
    Dirs = [
        reckon_dir(),
        socket_dir(),
        run_dir(),
        connectors_dir(),
        config_dir()
    ],
    lists:foreach(fun(Dir) -> ok = filelib:ensure_path(Dir) end, Dirs).

%%% Internal

expand_path("~/" ++ Rest) ->
    filename:join(os:getenv("HOME"), Rest);
expand_path(Path) ->
    Path.
