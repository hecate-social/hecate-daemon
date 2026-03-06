%%% @doc Projection: container_confirmed_up_v1 -> plugins table (UPDATE status).
-module(container_confirmed_up_v1_to_sqlite_plugins).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Event),
    %% Set CONFIRMED_UP(16), clear CONFIRMED_DOWN(32): status = (status | 16) & ~32
    Sql = "UPDATE plugins SET status = (status | 16) & ~32, "
          "status_label = 'Running' "
          "WHERE plugin_id = ?1",
    project_plugins_store:execute(Sql, [PluginId]).
