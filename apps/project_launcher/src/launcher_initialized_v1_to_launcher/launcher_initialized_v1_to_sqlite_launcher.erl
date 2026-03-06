%%% @doc Projection: launcher_initialized_v1 -> populate launcher tables from default groups.
-module(launcher_initialized_v1_to_sqlite_launcher).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    Groups = hecate_api_utils:get_field(groups, Event),
    %% Clear and rebuild from init payload
    project_launcher_store:execute("DELETE FROM launcher_entries"),
    project_launcher_store:execute("DELETE FROM launcher_groups"),
    lists:foldl(fun(Group, GPos) ->
        Name = get_value(name, Group),
        Icon = get_value(icon, Group, <<"📁">>),
        Collapsed = case get_value(collapsed, Group, false) of true -> 1; _ -> 0 end,
        Apps = get_value(apps, Group, []),
        project_launcher_store:execute(
            "INSERT INTO launcher_groups (name, icon, collapsed, position) VALUES (?1, ?2, ?3, ?4)",
            [Name, Icon, Collapsed, GPos]),
        lists:foldl(fun(AppId, EPos) ->
            project_launcher_store:execute(
                "INSERT INTO launcher_entries (entry_id, display_name, icon, group_name, position, status, status_label) "
                "VALUES (?1, ?1, '🔌', ?2, ?3, 1, 'Active')",
                [AppId, Name, EPos]),
            EPos + 1
        end, 0, Apps),
        GPos + 1
    end, 0, Groups),
    ok.

%% Internal

-spec get_value(atom(), map()) -> term().
get_value(Key, Map) when is_map(Map) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(BinKey, Map)
    end.

-spec get_value(atom(), map(), term()) -> term().
get_value(Key, Map, Default) when is_map(Map) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(BinKey, Map, Default)
    end.
