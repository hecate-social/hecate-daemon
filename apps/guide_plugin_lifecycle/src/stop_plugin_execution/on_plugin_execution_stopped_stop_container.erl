%%% @doc Process Manager: On plugin execution stopped, stop the container.
%%%
%%% Subscribes to plugin_execution_stopped_v1 events via evoq_event_handler.
%%% Calls shared_systemctl to stop the plugin's systemd service.
-module(on_plugin_execution_stopped_stop_container).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_execution_stopped_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    stop_container(PluginId),
    {ok, State}.

stop_container(PluginId) ->
    case resolve_daemon_name(PluginId) of
        undefined ->
            logger:error("[PM] Cannot resolve daemon name for plugin ~s", [PluginId]);
        DaemonName ->
            ServiceName = <<DaemonName/binary, ".service">>,
            case shared_systemctl:reload_and_stop(ServiceName) of
                ok ->
                    logger:info("[PM] Stopped service ~s for plugin ~s",
                                [ServiceName, PluginId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to stop service ~s: ~p",
                                 [ServiceName, Reason])
            end
    end.

resolve_daemon_name(PluginId) ->
    case project_plugins_store:get(PluginId) of
        {ok, #{oci_image := OciImage}} -> extract_daemon_name(OciImage);
        _ -> undefined
    end.

extract_daemon_name(OciImage) ->
    Base = strip_tag(OciImage),
    case binary:matches(Base, <<"/">>) of
        [] -> Base;
        Matches ->
            {Pos, Len} = lists:last(Matches),
            binary:part(Base, Pos + Len, byte_size(Base) - Pos - Len)
    end.

strip_tag(Image) ->
    case binary:matches(Image, <<":">>) of
        [] -> Image;
        Matches ->
            {Pos, _} = lists:last(Matches),
            Tag = binary:part(Image, Pos + 1, byte_size(Image) - Pos - 1),
            case binary:match(Tag, <<"/">>) of
                nomatch -> binary:part(Image, 0, Pos);
                _ -> Image
            end
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
