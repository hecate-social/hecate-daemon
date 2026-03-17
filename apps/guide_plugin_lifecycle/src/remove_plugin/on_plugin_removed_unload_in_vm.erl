%%% @doc Process Manager: On plugin removed, unload in-VM plugin.
%%%
%%% Subscribes to plugin_removed_v1 events via evoq_event_handler.
%%% Calls hecate_plugin_loader:unload_plugin/1 to remove routes,
%%% purge BEAM modules, and stop the supervision tree.
%%%
%%% Safe to call for container plugins — unload returns {error, not_loaded}.
%%% @end
-module(on_plugin_removed_unload_in_vm).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_removed_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    Name = sanitize_plugin_name(PluginId),
    case hecate_plugin_loader:unload_plugin(Name) of
        ok ->
            logger:info("[PM] In-VM plugin ~s unloaded on remove", [Name]);
        {error, not_loaded} ->
            ok;
        {error, Reason} ->
            logger:error("[PM] Failed to unload in-VM plugin ~s on remove: ~p",
                         [Name, Reason])
    end,
    {ok, State}.

%% Internal

sanitize_plugin_name(Name) when is_binary(Name) ->
    case binary:split(Name, <<"/">>) of
        [_, Short] -> Short;
        [Single] -> Single
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
