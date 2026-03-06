%%% @doc API handler: GET/PUT /api/launcher/layout
%%%
%%% GET  - Returns the full launcher layout from SQLite read model.
%%% PUT  - Delegates to reorganize_launcher_api for full layout update.
%%% @end
-module(get_launcher_layout_api).

-export([init/2, routes/0]).

-ifdef(TEST).
-compile(export_all).
-compile(nowarn_export_all).
-endif.

routes() -> [{"/api/launcher/layout", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        <<"PUT">> -> reorganize_launcher_api:handle_put(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_launcher_store:query(
        "SELECT name, icon, collapsed, position "
        "FROM launcher_groups ORDER BY position ASC") of
        {ok, GroupRows} ->
            Groups = lists:map(fun(Row) -> group_with_entries(Row) end, GroupRows),
            hecate_api_utils:json_ok(#{groups => Groups}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

group_with_entries([Name, Icon, Collapsed, _Pos]) ->
    {ok, EntryRows} = project_launcher_store:query(
        "SELECT entry_id FROM launcher_entries "
        "WHERE group_name = ?1 ORDER BY position ASC",
        [Name]),
    Apps = [EId || [EId] <- EntryRows],
    #{
        name => Name,
        icon => Icon,
        collapsed => Collapsed =:= 1,
        apps => Apps
    }.
