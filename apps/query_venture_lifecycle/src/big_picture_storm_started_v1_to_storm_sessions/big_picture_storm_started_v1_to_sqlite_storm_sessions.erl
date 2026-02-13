%%% @doc Projection: big_picture_storm_started_v1 -> storm_sessions table
-module(big_picture_storm_started_v1_to_sqlite_storm_sessions).
-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    StormNumber = get(storm_number, Event),
    StartedAt = get(started_at, Event),
    logger:info("[PROJECTION] ~s: projecting storm ~p for ~s", [?MODULE, StormNumber, VentureId]),
    Sql = "INSERT INTO storm_sessions (venture_id, storm_number, phase, started_at) "
          "VALUES (?1, ?2, 'storm', ?3)",
    query_venture_lifecycle_store:execute(Sql, [VentureId, StormNumber, StartedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
