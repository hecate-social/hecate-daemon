%%% @doc Process Manager: On plugin execution started, start container.
%%%
%%% Subscribes to plugin_execution_started_v1 events from plugins_store.
%%% Provisions the .container Quadlet file and data directory, then
%%% starts the systemd service.
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
        _ -> ok  %% Skip events during replay — reconciliation handles them
    end,
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal — event handling

handle_event(#evoq_event{event_type = ?EVENT_TYPE, data = Data}) ->
    PluginId = get_value(plugin_id, Data),
    OciImage = get_value(oci_image, Data),
    start_container(PluginId, OciImage);
handle_event(#evoq_event{event_type = Type}) ->
    logger:debug("[start-pm] Ignoring event ~s (expected ~s)", [Type, ?EVENT_TYPE]);
handle_event(_) ->
    ok.

start_container(PluginId, undefined) ->
    logger:error("[start-pm] No oci_image in event for ~s, cannot start container", [PluginId]);
start_container(PluginId, OciImage) ->
    DaemonName = shared_podman:extract_daemon_name(OciImage),
    ServiceName = <<DaemonName/binary, ".service">>,
    case shared_systemctl:reload_and_start(ServiceName) of
        ok ->
            logger:info("[start-pm] Started service ~s for plugin ~s",
                        [ServiceName, PluginId]);
        {error, Reason} ->
            logger:error("[start-pm] Failed to start service ~s: ~p",
                         [ServiceName, Reason])
    end.

%% Internal — startup reconciliation
%% NOTE: Reading from project_plugins_store here is acceptable because this runs
%% on a timer after startup (not in the event flow). It reconciles plugins that
%% should be running but whose containers may have stopped during downtime.

reconcile_running_plugins() ->
    try project_plugins_store:list_by_status(4) of
        {ok, Plugins} ->
            lists:foreach(fun(#{oci_image := OciImage} = P) ->
                PluginId = maps:get(plugin_id, P, <<"unknown">>),
                DaemonName = shared_podman:extract_daemon_name(OciImage),
                Filename = shared_podman:container_filename(DaemonName),
                ensure_quadlet_symlink(Filename, PluginId),
                ServiceName = <<DaemonName/binary, ".service">>,
                case shared_systemctl:reload_and_start(ServiceName) of
                    ok -> ok;
                    {error, Reason} ->
                        logger:warning("[start-pm] Reconcile: failed to start ~s: ~p",
                                       [ServiceName, Reason])
                end
            end, Plugins);
        {error, Reason} ->
            logger:warning("[start-pm] Startup reconciliation failed: ~p", [Reason])
    catch
        error:badarg -> ok
    end.

ensure_quadlet_symlink(Filename, PluginId) ->
    AppsDir = shared_paths:gitops_apps_dir(),
    FilePath = filename:join(AppsDir, Filename),
    case filelib:is_regular(FilePath) of
        false -> ok;
        true ->
            QuadletDir = filename:join([os:getenv("HOME"), ".config", "containers", "systemd"]),
            ok = filelib:ensure_path(QuadletDir),
            LinkPath = filename:join(QuadletDir, Filename),
            _ = file:delete(LinkPath),
            case file:make_symlink(FilePath, LinkPath) of
                ok ->
                    logger:info("[start-pm] Ensured Quadlet symlink for ~s", [PluginId]);
                {error, Reason} ->
                    logger:error("[start-pm] Failed to symlink Quadlet for ~s: ~p",
                                 [PluginId, Reason])
            end
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
