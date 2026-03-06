%%% @doc API handler: GET/POST /api/launcher/entries
%%%
%%% GET  - Returns all launcher entries as a flat list (SQLite read model).
%%% POST - Delegates to register_entry_api for entry registration.
%%% @end
-module(get_launcher_entries_api).

-export([init/2, routes/0]).

-ifdef(TEST).
-compile(export_all).
-compile(nowarn_export_all).
-endif.

-define(ENTRY_COLUMNS, [
    entry_id, display_name, icon, group_name,
    position, registered_at, status, status_label
]).

-define(SQL,
    "SELECT entry_id, display_name, icon, group_name, "
    "position, registered_at, status, status_label "
    "FROM launcher_entries ORDER BY group_name ASC, position ASC").

routes() -> [{"/api/launcher/entries", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        <<"POST">> -> register_entry_api:handle_post(Req0);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_launcher_store:query(?SQL) of
        {ok, Rows} ->
            Items = [row_to_map(R) || R <- Rows],
            hecate_api_utils:json_ok(#{entries => Items}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

row_to_map(Row) when is_list(Row) ->
    maps:from_list(lists:zip(?ENTRY_COLUMNS, Row));
row_to_map(Row) when is_tuple(Row) ->
    maps:from_list(lists:zip(?ENTRY_COLUMNS, tuple_to_list(Row))).
