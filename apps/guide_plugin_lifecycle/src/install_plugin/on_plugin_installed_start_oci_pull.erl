%%% @doc Process Manager: plugin_installed_v1 -> start_oci_pull_v1
%%%
%%% When a plugin is installed, automatically start pulling its OCI image.
%%% Reads plugin_id and oci_image directly from the event data.
%%% @end
-module(on_plugin_installed_start_oci_pull).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"plugin_installed_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = hecate_api_utils:get_field(plugin_id, Data),
    OciImage = hecate_api_utils:get_field(oci_image, Data),
    logger:info("[PM] Plugin ~s installed, starting OCI pull", [PluginId]),
    case start_oci_pull_v1:new(#{plugin_id => PluginId, oci_image => OciImage}) of
        {ok, Cmd} ->
            case maybe_start_oci_pull:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] OCI pull started for ~s", [PluginId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to start OCI pull for ~s: ~p", [PluginId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Failed to create pull command for ~s: ~p", [PluginId, Reason])
    end,
    {ok, State}.
