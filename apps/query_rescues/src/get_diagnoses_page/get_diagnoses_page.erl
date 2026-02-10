%%% @doc Query: list diagnoses for a division with pagination.
-module(get_diagnoses_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT diagnosis_id, division_id, incident_id, diagnosis, root_cause, "
          "diagnosed_by, diagnosed_at "
          "FROM diagnoses WHERE division_id = ?1 "
          "ORDER BY diagnosed_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_rescues_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({DiagnosisId, DivisionId, IncidentId, Diagnosis, RootCause,
            DiagnosedBy, DiagnosedAt}) ->
    #{
        diagnosis_id => DiagnosisId,
        division_id => DivisionId,
        incident_id => IncidentId,
        diagnosis => Diagnosis,
        root_cause => RootCause,
        diagnosed_by => DiagnosedBy,
        diagnosed_at => DiagnosedAt
    };
row_to_map([DiagnosisId, DivisionId, IncidentId, Diagnosis, RootCause,
            DiagnosedBy, DiagnosedAt]) ->
    row_to_map({DiagnosisId, DivisionId, IncidentId, Diagnosis, RootCause,
                DiagnosedBy, DiagnosedAt}).
