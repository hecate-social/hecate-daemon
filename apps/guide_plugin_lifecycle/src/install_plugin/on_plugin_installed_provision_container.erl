%%% @doc Process Manager: On plugin installed, provision a Quadlet container.
%%%
%%% Subscribes to plugin_installed_v1 events from plugins_store.
%%% Generates a .container Quadlet file and writes it to
%%% ~/.hecate/gitops/apps/ so the local reconciler picks it up.
%%% @end
-module(on_plugin_installed_provision_container).
-behaviour(gen_server).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"plugin_installed_v1">>).
-define(SUB_NAME, <<"on_plugin_installed_provision_container">>).
-define(STORE_ID, plugins_store).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = reckon_evoq_adapter:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    lists:foreach(fun(E) -> handle_event(E) end, Events),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal

handle_event(Event) ->
    Map = projection_event:to_map(Event),
    PluginId = get_value(plugin_id, Map),
    OciImage = get_value(oci_image, Map),
    Name = extract_plugin_name(PluginId),
    AppsDir = shared_paths:gitops_apps_dir(),
    ok = filelib:ensure_path(AppsDir),
    FilePath = filename:join(AppsDir, container_filename(Name)),
    Content = render_container(Name, OciImage),
    case file:write_file(FilePath, Content) of
        ok ->
            logger:info("[PM] Provisioned container file ~s for plugin ~s",
                        [FilePath, PluginId]);
        {error, Reason} ->
            logger:error("[PM] Failed to write container file ~s: ~p",
                         [FilePath, Reason])
    end.

%% @private Extract the plugin name from a plugin_id like "hecate-social/trader".
extract_plugin_name(PluginId) ->
    case binary:split(PluginId, <<"/">>) of
        [_, Name] -> Name;
        [Name] -> Name
    end.

%% @private Build the .container filename for a plugin.
container_filename(Name) ->
    <<"hecate-", Name/binary, "d.container">>.

%% @private Render the Quadlet .container file content.
render_container(Name, OciImage) ->
    iolist_to_binary([
        "[Unit]\n",
        "Description=Hecate ", Name, " (plugin)\n",
        "After=hecate-daemon.service\n",
        "Wants=hecate-daemon.service\n",
        "\n",
        "[Container]\n",
        "Image=", OciImage, "\n",
        "ContainerName=hecate-", Name, "d\n",
        "AutoUpdate=registry\n",
        "Network=host\n",
        "Environment=HOME=%h\n",
        "Volume=%h/.hecate/hecate-", Name, "d:%h/.hecate/hecate-", Name, "d:Z\n",
        "Volume=%h/.hecate/hecate-daemon/sockets:%h/.hecate/hecate-daemon/sockets:ro\n",
        "HealthCmd=test -S %h/.hecate/hecate-", Name, "d/sockets/api.sock\n",
        "HealthInterval=30s\n",
        "HealthRetries=3\n",
        "HealthTimeout=5s\n",
        "HealthStartPeriod=10s\n",
        "\n",
        "[Service]\n",
        "Restart=on-failure\n",
        "RestartSec=5s\n",
        "TimeoutStartSec=60s\n",
        "\n",
        "[Install]\n",
        "WantedBy=default.target\n"
    ]).

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
