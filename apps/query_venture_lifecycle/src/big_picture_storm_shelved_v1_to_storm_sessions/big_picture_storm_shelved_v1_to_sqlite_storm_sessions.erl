%%% @doc Projection: big_picture_storm_shelved_v1 -> storm_sessions table
-module(big_picture_storm_shelved_v1_to_sqlite_storm_sessions).
-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    ShelvedAt = get(shelved_at, Event),
    logger:info("[PROJECTION] ~s: shelving storm for ~s", [?MODULE, VentureId]),
    Sql = "UPDATE storm_sessions SET shelved_at = ?1 "
          "WHERE venture_id = ?2 AND storm_number = "
          "(SELECT MAX(storm_number) FROM storm_sessions WHERE venture_id = ?2)",
    query_venture_lifecycle_store:execute(Sql, [ShelvedAt, VentureId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
