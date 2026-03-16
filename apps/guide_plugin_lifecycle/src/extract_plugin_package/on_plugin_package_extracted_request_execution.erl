%%% @doc Process Manager: On plugin package extracted, request execution.
%%%
%%% Subscribes to plugin_package_extracted_v1 events.
%%% Dispatches request_plugin_execution_v1 command so the in-VM PM
%%% picks it up and loads the BEAM code.
-module(on_plugin_package_extracted_request_execution).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"plugin_package_extracted_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    case request_plugin_execution_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} ->
            case maybe_request_plugin_execution:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[extract-pm] Dispatched request_plugin_execution for ~s", [PluginId]);
                {error, Reason} ->
                    logger:error("[extract-pm] Failed to dispatch request_plugin_execution for ~s: ~p",
                                 [PluginId, Reason])
            end;
        {error, Reason} ->
            logger:error("[extract-pm] Invalid request_plugin_execution command for ~s: ~p",
                         [PluginId, Reason])
    end,
    {ok, State}.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, null} -> undefined;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
