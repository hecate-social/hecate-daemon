%%% @doc Process Manager: On plugin execution started, activate plugin.
%%%
%%% Subscribes to plugin_execution_started_v1 events from plugins_store.
%%% For container plugins: provisions .container Quadlet and starts systemd.
%%% For in-VM plugins: loads BEAM code via hecate_plugin_loader.
%%%
%%% On startup, reconciles installed+running plugins to catch events
%%% missed during downtime.
%%% @end
-module(on_plugin_execution_started_start_container).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"plugin_execution_started_v1">>).
-define(SUB_NAME, <<"on_plugin_execution_started_start_container">>).
-define(STORE_ID, plugins_store).
-define(READINESS_POLL_MS, 1000).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = evoq_subscriptions:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    erlang:send_after(?READINESS_POLL_MS, self(), await_ready),
    {ok, #{}}.

handle_info(await_ready, State) ->
    case hecate_lifecycle:get_state() of
        running ->
            reconcile_running_plugins(),
            {noreply, State};
        _ ->
            erlang:send_after(?READINESS_POLL_MS, self(), await_ready),
            {noreply, State}
    end;
handle_info({events, Events}, State) ->
    case hecate_lifecycle:get_state() of
        running -> lists:foreach(fun handle_event/1, Events);
        _ -> ok
    end,
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal — event dispatch

handle_event(#evoq_event{event_type = ?EVENT_TYPE, data = Data}) ->
    activate_plugin(
        get_value(plugin_id, Data),
        get_value(plugin_type, Data, <<"container">>),
        Data);
handle_event(_) ->
    ok.

activate_plugin(PluginId, <<"in_vm">>, Data) ->
    start_in_vm(PluginId, get_value(name, Data), get_value(callback_module, Data));
activate_plugin(PluginId, _, Data) ->
    start_container(PluginId, get_value(oci_image, Data)).

%% In-VM: load BEAM code via plugin loader

start_in_vm(PluginId, _Name, undefined) ->
    logger:error("[start-pm] In-VM plugin ~s has no callback_module", [PluginId]);
start_in_vm(PluginId, Name, CallbackModule) when is_binary(CallbackModule) ->
    Mod = binary_to_atom(CallbackModule, utf8),
    PluginName = resolve_plugin_name(Name, PluginId),
    logger:info("[start-pm] Loading in-VM plugin ~s (callback: ~p)", [PluginName, Mod]),
    log_load_result(PluginName, hecate_plugin_loader:load_plugin(PluginName, Mod)).

log_load_result(Name, ok) ->
    logger:info("[start-pm] In-VM plugin ~s loaded", [Name]);
log_load_result(Name, {error, already_loaded}) ->
    logger:info("[start-pm] In-VM plugin ~s already loaded", [Name]);
log_load_result(Name, {error, Reason}) ->
    logger:error("[start-pm] Failed to load in-VM plugin ~s: ~p", [Name, Reason]).

resolve_plugin_name(N, _Fallback) when is_binary(N), byte_size(N) > 0 -> N;
resolve_plugin_name(_, Fallback) -> Fallback.

%% Container: start systemd service

start_container(PluginId, undefined) ->
    logger:error("[start-pm] No oci_image for ~s, cannot start container", [PluginId]);
start_container(PluginId, OciImage) when is_binary(OciImage) ->
    DaemonName = shared_podman:extract_daemon_name(OciImage),
    ServiceName = <<DaemonName/binary, ".service">>,
    log_service_result(PluginId, ServiceName, shared_systemctl:reload_and_start(ServiceName)).

log_service_result(PluginId, ServiceName, ok) ->
    logger:info("[start-pm] Started service ~s for ~s", [ServiceName, PluginId]);
log_service_result(PluginId, ServiceName, {error, Reason}) ->
    logger:error("[start-pm] Failed to start ~s for ~s: ~p", [ServiceName, PluginId, Reason]).

%% Startup reconciliation

reconcile_running_plugins() ->
    try project_plugins_store:list_by_status(4) of
        {ok, Plugins} ->
            lists:foreach(fun reconcile_plugin/1, Plugins);
        {error, Reason} ->
            logger:warning("[start-pm] Reconciliation failed: ~p", [Reason])
    catch
        error:badarg -> ok
    end.

reconcile_plugin(#{plugin_type := <<"in_vm">>} = P) ->
    PluginId = maps:get(plugin_id, P, <<"unknown">>),
    start_in_vm(PluginId, maps:get(name, P, PluginId), maps:get(callback_module, P, undefined));
reconcile_plugin(#{oci_image := OciImage, plugin_id := PluginId}) when is_binary(OciImage) ->
    DaemonName = shared_podman:extract_daemon_name(OciImage),
    Filename = shared_podman:container_filename(DaemonName),
    ensure_quadlet_symlink(Filename, PluginId),
    ServiceName = <<DaemonName/binary, ".service">>,
    log_service_result(PluginId, ServiceName, shared_systemctl:reload_and_start(ServiceName));
reconcile_plugin(_) ->
    ok.

ensure_quadlet_symlink(Filename, PluginId) ->
    AppsDir = shared_paths:gitops_apps_dir(),
    FilePath = filename:join(AppsDir, Filename),
    do_ensure_symlink(filelib:is_regular(FilePath), FilePath, Filename, PluginId).

do_ensure_symlink(false, _FilePath, _Filename, _PluginId) ->
    ok;
do_ensure_symlink(true, FilePath, Filename, PluginId) ->
    QuadletDir = filename:join([os:getenv("HOME"), ".config", "containers", "systemd"]),
    ok = filelib:ensure_path(QuadletDir),
    LinkPath = filename:join(QuadletDir, Filename),
    _ = file:delete(LinkPath),
    log_symlink_result(PluginId, file:make_symlink(FilePath, LinkPath)).

log_symlink_result(PluginId, ok) ->
    logger:info("[start-pm] Ensured Quadlet symlink for ~s", [PluginId]);
log_symlink_result(PluginId, {error, Reason}) ->
    logger:error("[start-pm] Failed to symlink Quadlet for ~s: ~p", [PluginId, Reason]).

%% Value extraction (handles null from JSON round-trip)

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, null} -> Default;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
