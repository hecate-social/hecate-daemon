%%% @doc Projection: incident_diagnosed_v1 -> diagnoses table
-module(incident_diagnosed_v1_to_sqlite_diagnoses).
-export([project/1]).

project(Event) ->
    DiagnosisId = get(diagnosis_id, Event),
    DivisionId = get(division_id, Event),
    IncidentId = get(incident_id, Event),
    RootCause = get(root_cause, Event),
    DiagnosedAt = get(diagnosed_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, DiagnosisId]),
    Sql = "INSERT OR REPLACE INTO diagnoses "
          "(diagnosis_id, division_id, incident_id, root_cause, diagnosed_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_division_alc_store:execute(Sql, [DiagnosisId, DivisionId, IncidentId,
                                           RootCause, DiagnosedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
