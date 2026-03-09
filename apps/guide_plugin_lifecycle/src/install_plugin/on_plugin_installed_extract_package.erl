%%% @doc Process Manager: plugin_installed_v1 (in_vm) -> extract_plugin_package_v1
%%%
%%% When an in-VM plugin is installed, automatically extract its package.
%%% Only reacts to plugins with plugin_type = <<"in_vm">>.
%%% @end
-module(on_plugin_installed_extract_package).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"plugin_installed_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    PluginType = get_value(plugin_type, Data, <<"container">>),
    do_handle(PluginType, PluginId, Data),
    {ok, State}.

%% Only in-VM plugins need package extraction
do_handle(<<"in_vm">>, PluginId, Data) ->
    CallbackModule = get_value(callback_module, Data),
    PackageUrl = get_value(package_url, Data),
    do_extract(PluginId, PackageUrl, CallbackModule);
do_handle(_, _PluginId, _Data) ->
    ok.

do_extract(PluginId, PackageUrl, _CB) when not is_binary(PackageUrl); byte_size(PackageUrl) =:= 0 ->
    logger:error("[PM] In-VM plugin ~s has no package_url, cannot extract", [PluginId]);
do_extract(PluginId, PackageUrl, CallbackModule) ->
    logger:info("[PM] In-VM plugin ~s installed, extracting package from ~s", [PluginId, PackageUrl]),
    dispatch_extract(PluginId, PackageUrl, CallbackModule).

dispatch_extract(PluginId, PackageUrl, CallbackModule) ->
    case extract_plugin_package_v1:new(#{
        plugin_id => PluginId,
        package_url => PackageUrl,
        callback_module => CallbackModule
    }) of
        {ok, Cmd} ->
            log_dispatch_result(PluginId, maybe_extract_plugin_package:dispatch(Cmd));
        {error, Reason} ->
            logger:error("[PM] Failed to create extract command for ~s: ~p",
                         [PluginId, Reason])
    end.

log_dispatch_result(PluginId, {ok, _, _}) ->
    logger:info("[PM] Package extraction started for ~s", [PluginId]);
log_dispatch_result(PluginId, {error, Reason}) ->
    logger:error("[PM] Failed to start extraction for ~s: ~p", [PluginId, Reason]).

get_value(Key, Data) -> get_value(Key, Data, undefined).
get_value(Key, Data, Default) when is_atom(Key) ->
    case maps:find(Key, Data) of
        {ok, null} -> Default;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Data, Default)
    end.
