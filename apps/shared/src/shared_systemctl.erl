%%% @doc Shared systemctl utilities for managing plugin containers.
%%%
%%% Uses systemctl --user to communicate with the host's systemd session.
%%% Requires the daemon to run in the host's user systemd scope
%%% (not inside a container).
%%% @end
-module(shared_systemctl).

-export([reload_and_start/1, reload_and_stop/1, reload/0]).

-ifdef(TEST).
-compile(export_all).
-compile(nowarn_export_all).
-endif.

%% @doc Reload systemd units and (re)start a plugin service.
%% Uses restart to ensure fresh bind mounts if the container was
%% already running with stale mounts. Restart also handles the case
%% where the service is not yet running (acts as start).
-spec reload_and_start(binary() | string()) -> ok | {error, term()}.
reload_and_start(ServiceName) ->
    _ = reset_failed(ServiceName),
    case reload() of
        ok -> restart_service(ServiceName);
        {error, _} = Err -> Err
    end.

%% @doc Reload systemd units and stop a plugin service.
-spec reload_and_stop(binary() | string()) -> ok | {error, term()}.
reload_and_stop(ServiceName) ->
    _ = stop_service(ServiceName),
    reload().

%% @doc Reload systemd unit files (daemon-reload).
%% Cleans up dangling symlinks in the Quadlet directory first,
%% because the Podman Quadlet generator aborts entirely if any
%% symlink target is missing.
-spec reload() -> ok | {error, term()}.
reload() ->
    cleanup_dangling_quadlet_symlinks(),
    Cmd = "systemctl --user daemon-reload",
    logger:info("[systemctl] ~s", [Cmd]),
    Port = open_port({spawn, Cmd}, [exit_status, stderr_to_stdout, binary]),
    collect_port(Port, "daemon-reload", []).

%% Internal

cleanup_dangling_quadlet_symlinks() ->
    QuadletDir = filename:join([os:getenv("HOME"), ".config", "containers", "systemd"]),
    Files = list_dir_safe(QuadletDir),
    Paths = [filename:join(QuadletDir, F) || F <- Files],
    Dangling = [P || P <- Paths, is_dangling_symlink(P)],
    lists:foreach(fun remove_dangling/1, Dangling).

list_dir_safe(Dir) ->
    case file:list_dir(Dir) of
        {ok, Files} -> Files;
        {error, _} -> []
    end.

is_dangling_symlink(Path) ->
    case file:read_link(Path) of
        {ok, Target} -> not filelib:is_file(Target);
        {error, _} -> false
    end.

remove_dangling(Path) ->
    {ok, Target} = file:read_link(Path),
    logger:info("[systemctl] Removing dangling symlink ~s -> ~s", [Path, Target]),
    file:delete(Path).

restart_service(ServiceName) ->
    systemctl("restart", ServiceName, ["--no-block"]).

reset_failed(ServiceName) ->
    systemctl("reset-failed", ServiceName).

stop_service(ServiceName) ->
    systemctl("stop", ServiceName).

systemctl(Action, ServiceName) ->
    systemctl(Action, ServiceName, []).

systemctl(Action, ServiceName, Flags) ->
    Name = to_list(ServiceName),
    FlagsStr = lists:flatten(lists:join(" ", Flags)),
    Cmd = lists:flatten(["systemctl --user ", FlagsStr, " ", Action, " ", Name]),
    logger:info("[systemctl] ~s", [Cmd]),
    Port = open_port({spawn, Cmd}, [exit_status, stderr_to_stdout, binary]),
    collect_port(Port, Action, []).

to_list(V) when is_binary(V) -> binary_to_list(V);
to_list(V) when is_list(V) -> V.

collect_port(Port, Method, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_port(Port, Method, [Data | Acc]);
        {Port, {exit_status, 0}} ->
            ok;
        {Port, {exit_status, Code}} ->
            Output = iolist_to_binary(lists:reverse(Acc)),
            logger:error("[systemctl] ~s failed (exit ~p): ~s", [Method, Code, Output]),
            {error, {systemctl_failed, Code, Output}}
    after 30000 ->
        catch port_close(Port),
        logger:error("[systemctl] ~s timed out after 30s", [Method]),
        {error, timeout}
    end.
