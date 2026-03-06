%%% @doc Projection: entry_unregistered_v1 -> launcher_entries (DELETE).
-module(entry_unregistered_v1_to_sqlite_launcher).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    EntryId = hecate_api_utils:get_field(entry_id, Event),
    Sql = "DELETE FROM launcher_entries WHERE entry_id = ?1",
    project_launcher_store:execute(Sql, [EntryId]).
