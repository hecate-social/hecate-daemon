%%% @doc Projection: plugin_installed_v1 -> licenses ETS read model.
%%% Marks the license as installed for the given plugin_id.
-module(plugin_installed_v1_to_licenses).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, licenses).

interested_in() -> [<<"plugin_installed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    PluginId = gf(plugin_id, Data),
    Version = gf(installed_version, Data),
    InstalledAt = gf(installed_at, Data),
    update_by_plugin_id(PluginId, Version, InstalledAt, State, RM).

update_by_plugin_id(PluginId, Version, InstalledAt, State, RM) ->
    All = ets:tab2list(licenses),
    Matches = [{K, L} || {K, #{plugin_id := PId} = L} <- All, PId =:= PluginId],
    lists:foldl(fun({Key, License}, {ok, SAcc, RMAcc}) ->
        Updated = License#{
            installed         => 1,
            installed_version => Version,
            installed_at      => InstalledAt
        },
        {ok, RMAcc2} = evoq_read_model:put(Key, Updated, RMAcc),
        {ok, SAcc, RMAcc2}
    end, {ok, State, RM}, Matches).

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
