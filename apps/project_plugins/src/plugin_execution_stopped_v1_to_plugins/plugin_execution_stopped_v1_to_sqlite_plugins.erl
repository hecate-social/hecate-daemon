%%% @doc Projection: plugin_execution_stopped_v1 -> plugins table (UPDATE status).
-module(plugin_execution_stopped_v1_to_sqlite_plugins).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Event),
    StoppedAt = hecate_api_utils:get_field(stopped_at, Event),
    %% Set STOPPED(8), clear RUNNING(4): status = (status | 8) & ~4
    Sql = "UPDATE plugins SET status = (status | 8) & ~4, "
          "status_label = 'Stopped', stopped_at = ?1 "
          "WHERE plugin_id = ?2",
    project_plugins_store:execute(Sql, [StoppedAt, PluginId]).
