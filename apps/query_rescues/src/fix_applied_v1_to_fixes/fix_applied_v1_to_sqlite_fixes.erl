%%% @doc Projection: fix_applied_v1 -> fixes table
-module(fix_applied_v1_to_sqlite_fixes).
-export([project/1]).

project(Event) ->
    FixId = get(fix_id, Event),
    DivisionId = get(division_id, Event),
    IncidentId = get(incident_id, Event),
    DiagnosisId = get(diagnosis_id, Event),
    FixDescription = get(fix_description, Event),
    FixType = get(fix_type, Event),
    AppliedBy = get(applied_by, Event),
    AppliedAt = get(applied_at, Event),
    Sql = "INSERT OR REPLACE INTO fixes "
          "(fix_id, division_id, incident_id, diagnosis_id, fix_description, "
          "fix_type, applied_by, applied_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
    query_rescues_store:execute(Sql, [FixId, DivisionId, IncidentId, DiagnosisId,
                                      FixDescription, FixType, AppliedBy, AppliedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
