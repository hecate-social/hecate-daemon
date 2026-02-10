%%% @doc Query: list fixes for a division with pagination.
-module(get_fixes_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT fix_id, division_id, incident_id, diagnosis_id, fix_description, "
          "fix_type, applied_by, applied_at "
          "FROM fixes WHERE division_id = ?1 "
          "ORDER BY applied_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_rescues_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({FixId, DivisionId, IncidentId, DiagnosisId, FixDescription,
            FixType, AppliedBy, AppliedAt}) ->
    #{
        fix_id => FixId,
        division_id => DivisionId,
        incident_id => IncidentId,
        diagnosis_id => DiagnosisId,
        fix_description => FixDescription,
        fix_type => FixType,
        applied_by => AppliedBy,
        applied_at => AppliedAt
    };
row_to_map([FixId, DivisionId, IncidentId, DiagnosisId, FixDescription,
            FixType, AppliedBy, AppliedAt]) ->
    row_to_map({FixId, DivisionId, IncidentId, DiagnosisId, FixDescription,
                FixType, AppliedBy, AppliedAt}).
