%%% @doc Projection: container_confirmed_down_v1 -> plugins table (UPDATE status).
-module(container_confirmed_down_v1_to_sqlite_plugins).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Event),
    %% Set CONFIRMED_DOWN(32), clear CONFIRMED_UP(16): status = (status | 32) & ~16
    Sql = "UPDATE plugins SET status = (status | 32) & ~16, "
          "status_label = 'Stopped' "
          "WHERE plugin_id = ?1",
    project_plugins_store:execute(Sql, [PluginId]).
