%%% @doc Query: list divisions with pagination.
-module(get_divisions_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT division_id, venture_id, context_name, overall_status, "
          "dna_status, anp_status, tni_status, dno_status, "
          "initiated_at, initiated_by "
          "FROM divisions "
          "ORDER BY initiated_at DESC "
          "LIMIT ?1 OFFSET ?2",
    case query_division_alc_store:query(Sql, [Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({DivisionId, VentureId, ContextName, OverallStatus,
            DnaStatus, AnpStatus, TniStatus, DnoStatus,
            InitiatedAt, InitiatedBy}) ->
    #{
        division_id => DivisionId,
        venture_id => VentureId,
        context_name => ContextName,
        overall_status => OverallStatus,
        dna_status => DnaStatus,
        anp_status => AnpStatus,
        tni_status => TniStatus,
        dno_status => DnoStatus,
        initiated_at => InitiatedAt,
        initiated_by => InitiatedBy
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).
