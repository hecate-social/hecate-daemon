%%% @doc Projection: big_picture_storm_archived_v1 -> storm_sessions table
-module(big_picture_storm_archived_v1_to_sqlite_storm_sessions).
-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    ArchivedAt = get(archived_at, Event, erlang:system_time(millisecond)),
    logger:info("[PROJECTION] ~s: archiving storm for ~s", [?MODULE, VentureId]),
    Sql = "UPDATE storm_sessions SET completed_at = ?1 "
          "WHERE venture_id = ?2 AND storm_number = "
          "(SELECT MAX(storm_number) FROM storm_sessions WHERE venture_id = ?2)",
    query_venture_lifecycle_store:execute(Sql, [ArchivedAt, VentureId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

get(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.
