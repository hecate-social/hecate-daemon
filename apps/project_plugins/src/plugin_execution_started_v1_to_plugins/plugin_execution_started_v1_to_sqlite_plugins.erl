%%% @doc Projection: plugin_execution_started_v1 -> plugins table (UPDATE status).
-module(plugin_execution_started_v1_to_sqlite_plugins).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Event),
    StartedAt = hecate_api_utils:get_field(started_at, Event),
    %% Set RUNNING(4), clear STOPPED(8): status = (status | 4) & ~8
    Sql = "UPDATE plugins SET status = (status | 4) & ~8, "
          "status_label = 'Running', started_at = ?1, stopped_at = NULL "
          "WHERE plugin_id = ?2",
    project_plugins_store:execute(Sql, [StartedAt, PluginId]).
