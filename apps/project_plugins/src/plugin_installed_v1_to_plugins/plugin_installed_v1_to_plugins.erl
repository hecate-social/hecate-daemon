%%% @doc Projection: plugin_installed_v1 -> plugins ETS read model.
%%% Inserts a new plugin record into the shared plugins table.
-module(plugin_installed_v1_to_plugins).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, plugins).

interested_in() -> [<<"plugin_installed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    PluginId = gf(plugin_id, Data),
    Plugin = #{
        plugin_id         => PluginId,
        name              => gf(name, Data),
        oci_image         => gf(oci_image, Data),
        installed_version => gf(installed_version, Data),
        license_id        => gf(license_id, Data),
        installed_at      => gf(installed_at, Data),
        upgraded_at       => undefined,
        removed_at        => undefined,
        started_at        => undefined,
        stopped_at        => undefined,
        status            => 1,
        status_label      => <<"Installed">>,
        icon              => gf(icon, Data),
        group_name        => gf(group_name, Data)
    },
    {ok, RM2} = evoq_read_model:put(PluginId, Plugin, RM),
    {ok, State, RM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
