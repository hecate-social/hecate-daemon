%%% @doc Projection: storm_phase_advanced_v1 -> storm_sessions table
-module(storm_phase_advanced_v1_to_sqlite_storm_sessions).
-export([project/1]).

project(Event) ->
    Phase = get(phase, Event),
    VentureId = get(venture_id, Event),
    logger:info("[PROJECTION] ~s: advancing phase to ~s for ~s", [?MODULE, Phase, VentureId]),
    Sql = "UPDATE storm_sessions SET phase = ?1 "
          "WHERE venture_id = ?2 AND storm_number = "
          "(SELECT MAX(storm_number) FROM storm_sessions WHERE venture_id = ?2)",
    query_venture_lifecycle_store:execute(Sql, [Phase, VentureId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
