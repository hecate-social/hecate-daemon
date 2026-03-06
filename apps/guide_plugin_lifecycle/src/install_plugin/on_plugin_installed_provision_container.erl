%%% @doc Process Manager: On plugin installed, provision a Quadlet container.
%%%
%%% Subscribes to plugin_installed_v1 events from plugins_store.
%%% Generates a .container Quadlet file and writes it to
%%% ~/.hecate/gitops/apps/ so the local reconciler picks it up.
%%%
%%% On startup, reconciles installed plugins against existing Quadlet
%%% files to catch events missed during downtime (crash, restart, etc.).
%%% @end
-module(on_plugin_installed_provision_container).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-ifdef(TEST).
-compile(export_all).
-compile(nowarn_export_all).
-endif.

-define(EVENT_TYPE, <<"plugin_installed_v1">>).
-define(SUB_NAME, <<"on_plugin_installed_provision_container">>).
-define(STORE_ID, plugins_store).
-define(RECONCILE_DELAY_MS, 5000).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = evoq_subscriptions:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    erlang:send_after(?RECONCILE_DELAY_MS, self(), reconcile),
    {ok, #{}}.

handle_info(reconcile, State) ->
    reconcile_installed_plugins(),
    {noreply, State};
handle_info({events, Events}, State) ->
    lists:foreach(fun(E) -> handle_event(E) end, Events),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal — event handling

handle_event(#evoq_event{data = Data}) ->
    PluginId = get_value(plugin_id, Data),
    OciImage = get_value(oci_image, Data),
    DaemonName = extract_daemon_name(OciImage),
    provision_container(PluginId, DaemonName, OciImage).

provision_container(PluginId, Name, OciImage) ->
    AppsDir = shared_paths:gitops_apps_dir(),
    ok = filelib:ensure_path(AppsDir),
    %% Create plugin data directory so podman can mount it
    PluginDataDir = plugin_data_dir(Name),
    ok = filelib:ensure_path(PluginDataDir),
    FilePath = filename:join(AppsDir, container_filename(Name)),
    Content = render_container(Name, OciImage),
    case file:write_file(FilePath, Content) of
        ok ->
            logger:info("[PM] Provisioned container file ~s for plugin ~s",
                        [FilePath, PluginId]),
            ServiceName = service_name(Name),
            case shared_systemctl:reload_and_start(ServiceName) of
                ok ->
                    logger:info("[PM] Started service ~s", [ServiceName]);
                {error, Reason} ->
                    logger:error("[PM] Failed to start service ~s: ~p",
                                 [ServiceName, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Failed to write container file ~s: ~p",
                         [FilePath, Reason])
    end.

%% Internal — startup reconciliation

reconcile_installed_plugins() ->
    case query_installed_plugins() of
        {ok, Plugins} ->
            lists:foreach(fun reconcile_plugin/1, Plugins);
        {error, Reason} ->
            logger:warning("[PM] Startup reconciliation failed: ~p", [Reason])
    end.

reconcile_plugin({PluginId, OciImage}) ->
    Name = extract_daemon_name(OciImage),
    FilePath = filename:join(shared_paths:gitops_apps_dir(), container_filename(Name)),
    case filelib:is_regular(FilePath) of
        true -> ok;
        false -> provision_container(PluginId, Name, OciImage)
    end.

%% @private Query SQLite for installed (non-removed) plugins.
%% Catches specific exit reasons because project_plugins_store
%% may not be started yet during early daemon boot.
query_installed_plugins() ->
    Sql = "SELECT plugin_id, oci_image FROM plugins WHERE (status & 2) = 0",
    try project_plugins_store:query(Sql) of
        {ok, Rows} ->
            {ok, [row_to_tuple(R) || R <- Rows]};
        {error, _} = Err ->
            Err
    catch
        exit:{noproc, _} -> {error, store_not_ready};
        exit:{timeout, _} -> {error, store_timeout}
    end.

row_to_tuple([PluginId, OciImage]) -> {PluginId, OciImage};
row_to_tuple({PluginId, OciImage}) -> {PluginId, OciImage}.

%% @private Extract the daemon name from the OCI image reference.
%% "ghcr.io/hecate-apps/hecate-app-snake-dueld:latest" -> "hecate-app-snake-dueld"
%% "ghcr.io/hecate-apps/hecate-app-snake-dueld" -> "hecate-app-snake-dueld"
extract_daemon_name(OciImage) ->
    Base = strip_tag(OciImage),
    case split_last(Base, <<"/">>) of
        {_, Name} -> Name;
        nomatch -> Base
    end.

%% @private Build the plugin data directory path.
plugin_data_dir(DaemonName) ->
    filename:join(shared_paths:hecate_home(), DaemonName).

%% @private Build the .container filename for a plugin.
container_filename(DaemonName) ->
    <<DaemonName/binary, ".container">>.

%% @private Build the systemd service name for a plugin.
service_name(DaemonName) ->
    <<DaemonName/binary, ".service">>.

%% @private Render the Quadlet .container file content.
render_container(DaemonName, OciImage) ->
    BaseImage = strip_tag(OciImage),
    iolist_to_binary([
        "[Unit]\n",
        "Description=Hecate ", DaemonName, " (plugin)\n",
        "After=hecate-daemon.service\n",
        "Wants=hecate-daemon.service\n",
        "\n",
        "[Container]\n",
        "Image=", BaseImage, ":latest\n",
        "ContainerName=", DaemonName, "\n",
        "AutoUpdate=registry\n",
        "Network=host\n",
        "Environment=HOME=%h\n",
        "Volume=%h/.hecate/", DaemonName, ":%h/.hecate/", DaemonName, ":Z\n",
        "Volume=%h/.hecate/hecate-daemon/sockets:%h/.hecate/hecate-daemon/sockets:ro\n",
        "HealthCmd=test -S %h/.hecate/", DaemonName, "/sockets/api.sock\n",
        "HealthInterval=30s\n",
        "HealthRetries=3\n",
        "HealthTimeout=5s\n",
        "HealthStartPeriod=10s\n",
        "\n",
        "[Service]\n",
        "Restart=always\n",
        "RestartSec=5s\n",
        "TimeoutStartSec=60s\n",
        "\n",
        "[Install]\n",
        "WantedBy=default.target\n"
    ]).

%% @private Strip the tag from an OCI image reference.
%% "ghcr.io/org/image:0.1.1" -> "ghcr.io/org/image"
%% "ghcr.io/org/image" -> "ghcr.io/org/image"
%% Tag is the part after the last colon that contains no slashes.
strip_tag(Image) ->
    case split_last(Image, <<":">>) of
        {Base, Tag} ->
            case binary:match(Tag, <<"/">>) of
                nomatch -> Base;
                _ -> Image
            end;
        nomatch -> Image
    end.

split_last(Bin, Sep) ->
    case binary:matches(Bin, Sep) of
        [] -> nomatch;
        Matches ->
            {Pos, Len} = lists:last(Matches),
            {binary:part(Bin, 0, Pos), binary:part(Bin, Pos + Len, byte_size(Bin) - Pos - Len)}
    end.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
