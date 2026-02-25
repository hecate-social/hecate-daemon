%%% @doc Shared path utilities for hecate-daemon.
%%%
%%% Provides purpose-specific path functions for the namespaced
%%% directory layout under ~/.hecate/hecate-daemon/:
%%%
%%%   sqlite/       - SQLite read-model databases
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
    config_dir/0,
    config_path/1,
    sqlite_dir/0,
    sqlite_path/1,
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
%% Default: ~/.hecate/hecate-daemon
-spec base_dir() -> file:filename().
base_dir() ->
    case application:get_env(hecate, data_dir) of
        {ok, Dir} -> expand_path(Dir);
        undefined -> expand_path("~/.hecate/hecate-daemon")
    end.

%% @doc Returns the hecate home directory (~/.hecate).
-spec hecate_home() -> file:filename().
hecate_home() ->
    filename:dirname(base_dir()).

%% @doc Returns the shared config directory (~/.hecate/config).
-spec config_dir() -> file:filename().
config_dir() ->
    filename:join(hecate_home(), "config").

%% @doc Returns the full path for a named config file.
-spec config_path(string() | binary()) -> file:filename().
config_path(Name) ->
    filename:join(config_dir(), Name).

%% @doc Returns the directory for SQLite database files.
-spec sqlite_dir() -> file:filename().
sqlite_dir() ->
    filename:join(base_dir(), "sqlite").

%% @doc Returns the full path for a SQLite database file.
-spec sqlite_path(string() | binary()) -> file:filename().
sqlite_path(Name) ->
    filename:join(sqlite_dir(), Name).

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
        sqlite_dir(),
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
