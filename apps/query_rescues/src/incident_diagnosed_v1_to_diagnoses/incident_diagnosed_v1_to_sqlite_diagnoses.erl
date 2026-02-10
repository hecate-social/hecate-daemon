%%% @doc Projection: incident_diagnosed_v1 -> diagnoses table
-module(incident_diagnosed_v1_to_sqlite_diagnoses).
-export([project/1]).

project(Event) ->
    DiagnosisId = get(diagnosis_id, Event),
    DivisionId = get(division_id, Event),
    IncidentId = get(incident_id, Event),
    Diagnosis = get(diagnosis, Event),
    RootCause = get(root_cause, Event),
    DiagnosedBy = get(diagnosed_by, Event),
    DiagnosedAt = get(diagnosed_at, Event),
    Sql = "INSERT OR REPLACE INTO diagnoses "
          "(diagnosis_id, division_id, incident_id, diagnosis, root_cause, "
          "diagnosed_by, diagnosed_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
    query_rescues_store:execute(Sql, [DiagnosisId, DivisionId, IncidentId, Diagnosis,
                                      RootCause, DiagnosedBy, DiagnosedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
