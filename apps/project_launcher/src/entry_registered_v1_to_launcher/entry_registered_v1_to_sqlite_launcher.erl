%%% @doc Projection: entry_registered_v1 -> launcher_entries + launcher_groups (INSERT).
-module(entry_registered_v1_to_sqlite_launcher).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    EntryId = hecate_api_utils:get_field(entry_id, Event),
    DisplayName = hecate_api_utils:get_field(display_name, Event),
    Icon = hecate_api_utils:get_field(icon, Event),
    GroupName = hecate_api_utils:get_field(group_name, Event),
    RegisteredAt = hecate_api_utils:get_field(registered_at, Event),
    %% Ensure group exists
    GroupSql = "INSERT OR IGNORE INTO launcher_groups (name, icon, collapsed, position) "
               "VALUES (?1, '📁', 0, (SELECT COALESCE(MAX(position),0)+1 FROM launcher_groups))",
    project_launcher_store:execute(GroupSql, [GroupName]),
    %% Insert entry
    EntrySql = "INSERT OR REPLACE INTO launcher_entries "
               "(entry_id, display_name, icon, group_name, position, registered_at, status, status_label) "
               "VALUES (?1, ?2, ?3, ?4, "
               "(SELECT COALESCE(MAX(position),0)+1 FROM launcher_entries WHERE group_name = ?4), "
               "?5, 1, 'Active')",
    project_launcher_store:execute(EntrySql, [EntryId, DisplayName, Icon, GroupName, RegisteredAt]).
