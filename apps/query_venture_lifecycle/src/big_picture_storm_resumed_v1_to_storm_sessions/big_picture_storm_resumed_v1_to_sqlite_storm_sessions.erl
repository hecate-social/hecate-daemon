%%% @doc Projection: big_picture_storm_resumed_v1 -> storm_sessions table
-module(big_picture_storm_resumed_v1_to_sqlite_storm_sessions).
-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    logger:info("[PROJECTION] ~s: resuming storm for ~s", [?MODULE, VentureId]),
    Sql = "UPDATE storm_sessions SET shelved_at = NULL "
          "WHERE venture_id = ?1 AND storm_number = "
          "(SELECT MAX(storm_number) FROM storm_sessions WHERE venture_id = ?1)",
    query_venture_lifecycle_store:execute(Sql, [VentureId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
