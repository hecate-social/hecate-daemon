%%% @doc Projection: fix_applied_v1 -> fixes table
-module(fix_applied_v1_to_sqlite_fixes).
-export([project/1]).

project(Event) ->
    FixId = get(fix_id, Event),
    DivisionId = get(division_id, Event),
    IncidentId = get(incident_id, Event),
    Description = get(description, Event),
    AppliedAt = get(applied_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, FixId]),
    Sql = "INSERT OR REPLACE INTO fixes "
          "(fix_id, division_id, incident_id, description, applied_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_division_alc_store:execute(Sql, [FixId, DivisionId, IncidentId,
                                           Description, AppliedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
