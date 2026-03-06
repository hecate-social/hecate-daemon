%%% @doc Process Manager: On plugin removed, deprovision the container.
%%%
%%% Subscribes to plugin_removed_v1 events from plugins_store.
%%% Deletes the .container Quadlet file from ~/.hecate/gitops/apps/
%%% so the local reconciler stops and removes the container.
%%% @end
-module(on_plugin_removed_deprovision_container).
-behaviour(gen_server).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"plugin_removed_v1">>).
-define(SUB_NAME, <<"on_plugin_removed_deprovision_container">>).
-define(STORE_ID, plugins_store).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = evoq_subscriptions:subscribe(
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
    case lookup_oci_image(PluginId) of
        {ok, OciImage} ->
            deprovision(PluginId, OciImage);
        {error, not_found} ->
            logger:warning("[PM] Cannot find OCI image for ~s, trying plugin_id fallback",
                           [PluginId]),
            deprovision_by_plugin_id(PluginId)
    end.

deprovision(PluginId, OciImage) ->
    DaemonName = extract_daemon_name(OciImage),
    AppsDir = shared_paths:gitops_apps_dir(),
    FilePath = filename:join(AppsDir, container_filename(DaemonName)),
    ServiceName = service_name(DaemonName),
    case shared_systemctl:reload_and_stop(ServiceName) of
        ok ->
            logger:info("[PM] Stopped service ~s", [ServiceName]);
        {error, Reason0} ->
            logger:warning("[PM] Failed to stop service ~s: ~p (continuing with file removal)",
                           [ServiceName, Reason0])
    end,
    case file:delete(FilePath) of
        ok ->
            logger:info("[PM] Deprovisioned container file ~s for plugin ~s",
                        [FilePath, PluginId]),
            _ = shared_systemctl:reload();
        {error, enoent} ->
            logger:info("[PM] Container file already absent for ~s, nothing to deprovision",
                        [PluginId]);
        {error, Reason} ->
            logger:error("[PM] Failed to delete container file ~s: ~p",
                         [FilePath, Reason])
    end.

%% @private Fallback: derive daemon name from plugin_id (legacy naming).
deprovision_by_plugin_id(PluginId) ->
    Name = case binary:split(PluginId, <<"/">>) of
        [_, N] -> N;
        [N] -> N
    end,
    LegacyDaemonName = <<"hecate-", Name/binary, "d">>,
    AppsDir = shared_paths:gitops_apps_dir(),
    FilePath = filename:join(AppsDir, <<LegacyDaemonName/binary, ".container">>),
    ServiceName = <<LegacyDaemonName/binary, ".service">>,
    case shared_systemctl:reload_and_stop(ServiceName) of
        ok -> ok;
        {error, _} -> ok
    end,
    case file:delete(FilePath) of
        ok ->
            logger:info("[PM] Deprovisioned (fallback) ~s", [FilePath]),
            _ = shared_systemctl:reload();
        _ -> ok
    end.

%% @private Look up the OCI image for a plugin from the read model.
lookup_oci_image(PluginId) ->
    Sql = <<"SELECT oci_image FROM plugins WHERE plugin_id = ?1 LIMIT 1">>,
    try project_plugins_store:query(Sql, [PluginId]) of
        {ok, [[OciImage]]} -> {ok, OciImage};
        {ok, []} -> {error, not_found};
        _ -> {error, not_found}
    catch
        _:_ -> {error, not_found}
    end.

%% @private Extract the daemon name from the OCI image reference.
extract_daemon_name(OciImage) ->
    Base = strip_tag(OciImage),
    case split_last(Base, <<"/">>) of
        {_, Name} -> Name;
        nomatch -> Base
    end.

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

%% @private Build the .container filename.
container_filename(DaemonName) ->
    <<DaemonName/binary, ".container">>.

%% @private Build the systemd service name.
service_name(DaemonName) ->
    <<DaemonName/binary, ".service">>.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
