%%% @doc Emitter: plugin_package_extracted_v1 -> web frontend via SSE.
%%%
%%% Subscribes to plugin_package_extracted_v1 and broadcasts the current plugin
%%% state to connected web clients via hecate_web_events.
%%% @end
-module(plugin_package_extracted_v1_to_web).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_package_extracted_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, #{data := Data}, _Metadata, State) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Data),
    case project_plugins_store:get(PluginId) of
        {ok, Plugin} ->
            hecate_web_events:broadcast(plugin_status_changed, #{
                plugin_id         => PluginId,
                name              => maps:get(name, Plugin, PluginId),
                status            => maps:get(status, Plugin, 0),
                status_label      => maps:get(status_label, Plugin, <<>>),
                available_actions => maps:get(available_actions, Plugin, [])
            });
        _ ->
            ok
    end,
    {ok, State};
handle_event(_EventType, _Event, _Metadata, State) ->
    {ok, State}.
