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
    Name = extract_plugin_name(PluginId),
    AppsDir = shared_paths:gitops_apps_dir(),
    FilePath = filename:join(AppsDir, container_filename(Name)),
    case file:delete(FilePath) of
        ok ->
            logger:info("[PM] Deprovisioned container file ~s for plugin ~s",
                        [FilePath, PluginId]);
        {error, enoent} ->
            logger:info("[PM] Container file already absent for ~s, nothing to deprovision",
                        [PluginId]);
        {error, Reason} ->
            logger:error("[PM] Failed to delete container file ~s: ~p",
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

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
