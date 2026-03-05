%%% @doc Shared systemctl utilities for managing plugin containers.
%%%
%%% Uses dbus-send to communicate with the host's systemd user session.
%%% Requires:
%%%   - DBUS_SESSION_BUS_ADDRESS env var set
%%%   - Host's D-Bus socket mounted into the container
%%%   - dbus package installed in the runtime image
%%% @end
-module(shared_systemctl).

-export([reload_and_start/1, reload_and_stop/1, reload/0]).

-ifdef(TEST).
-compile(export_all).
-compile(nowarn_export_all).
-endif.

%% @doc Reload systemd units and start a plugin service.
-spec reload_and_start(binary() | string()) -> ok | {error, term()}.
reload_and_start(ServiceName) ->
    case reload() of
        ok -> start_service(ServiceName);
        {error, _} = Err -> Err
    end.

%% @doc Reload systemd units and stop a plugin service.
-spec reload_and_stop(binary() | string()) -> ok | {error, term()}.
reload_and_stop(ServiceName) ->
    _ = stop_service(ServiceName),
    reload().

%% @doc Reload systemd unit files (daemon-reload).
-spec reload() -> ok | {error, term()}.
reload() ->
    dbus_call("Reload", []).

%% Internal

start_service(ServiceName) ->
    dbus_call("StartUnit", [string_arg(ServiceName), string_arg("replace")]).

stop_service(ServiceName) ->
    dbus_call("StopUnit", [string_arg(ServiceName), string_arg("replace")]).

string_arg(V) when is_binary(V) -> ["string:", binary_to_list(V)];
string_arg(V) when is_list(V) -> ["string:", V].

dbus_call(Method, Args) ->
    ArgsStr = lists:flatten(lists:join(" ", [lists:flatten(A) || A <- Args])),
    Cmd = lists:flatten([
        "dbus-send --session --type=method_call --print-reply --dest=org.freedesktop.systemd1 ",
        "/org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.", Method,
        case ArgsStr of
            [] -> "";
            _ -> [" ", ArgsStr]
        end
    ]),
    logger:info("[systemctl] ~s", [Cmd]),
    Port = open_port({spawn, Cmd}, [exit_status, stderr_to_stdout, binary]),
    collect_port(Port, Method, []).

collect_port(Port, Method, Acc) ->
    receive
        {Port, {data, Data}} ->
            collect_port(Port, Method, [Data | Acc]);
        {Port, {exit_status, 0}} ->
            ok;
        {Port, {exit_status, Code}} ->
            Output = iolist_to_binary(lists:reverse(Acc)),
            logger:error("[systemctl] ~s failed (exit ~p): ~s", [Method, Code, Output]),
            {error, {dbus_failed, Code, Output}}
    after 30000 ->
        catch port_close(Port),
        logger:error("[systemctl] ~s timed out after 30s", [Method]),
        {error, timeout}
    end.
