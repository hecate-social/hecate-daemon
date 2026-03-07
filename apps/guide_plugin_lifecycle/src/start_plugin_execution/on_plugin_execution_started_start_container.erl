%%% @doc Process Manager: On plugin execution started, start container.
%%%
%%% Subscribes to plugin_execution_started_v1 events from plugins_store.
%%% Container provisioning and image pulling are handled by the pull PM.
%%% This PM only starts the systemd service (image should be cached).
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
    reconcile_running_plugins(),
    {noreply, State};
handle_info({events, Events}, State) ->
    lists:foreach(fun handle_event/1, Events),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal — event handling

handle_event(#evoq_event{event_type = ?EVENT_TYPE, data = Data}) ->
    PluginId = get_value(plugin_id, Data),
    start_container(PluginId);
handle_event(#evoq_event{event_type = Type}) ->
    logger:debug("[start-pm] Ignoring event ~s (expected ~s)", [Type, ?EVENT_TYPE]);
handle_event(_) ->
    ok.

start_container(PluginId) ->
    case resolve_plugin_info(PluginId) of
        undefined ->
            logger:error("[PM] Cannot resolve plugin info for ~s", [PluginId]);
        {DaemonName, _OciImage} ->
            ServiceName = <<DaemonName/binary, ".service">>,
            case shared_systemctl:reload_and_start(ServiceName) of
                ok ->
                    logger:info("[PM] Started service ~s for plugin ~s",
                                [ServiceName, PluginId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to start service ~s: ~p",
                                 [ServiceName, Reason])
            end
    end.

%% Internal — startup reconciliation

reconcile_running_plugins() ->
    case query_running_plugins() of
        {ok, Plugins} ->
            lists:foreach(fun({_PluginId, OciImage}) ->
                DaemonName = shared_podman:extract_daemon_name(OciImage),
                ServiceName = <<DaemonName/binary, ".service">>,
                case shared_systemctl:reload_and_start(ServiceName) of
                    ok -> ok;
                    {error, Reason} ->
                        logger:warning("[PM] Reconcile: failed to start ~s: ~p",
                                       [ServiceName, Reason])
                end
            end, Plugins);
        {error, Reason} ->
            logger:warning("[PM] Startup reconciliation failed: ~p", [Reason])
    end.

%% @private Query plugins with RUNNING flag set (status & 4).
query_running_plugins() ->
    try project_plugins_store:list_by_status(4) of
        {ok, Plugins} ->
            Running = [{maps:get(plugin_id, P), maps:get(oci_image, P)}
                       || P <- Plugins, maps:get(status, P) band 2 =:= 0],
            {ok, Running};
        {error, _} = Err ->
            Err
    catch
        error:badarg -> {error, store_not_ready}
    end.

%% @private Look up oci_image from plugins read model.
resolve_plugin_info(PluginId) ->
    case project_plugins_store:get(PluginId) of
        {ok, #{oci_image := OciImage}} ->
            {shared_podman:extract_daemon_name(OciImage), OciImage};
        _ -> undefined
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
