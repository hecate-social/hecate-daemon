%%% @doc Query: list incidents for a division with pagination.
-module(get_incidents_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT incident_id, division_id, incident_title, severity, "
          "description, raised_at "
          "FROM incidents WHERE division_id = ?1 "
          "ORDER BY raised_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_monitoring_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({IncidentId, DivisionId, IncidentTitle, Severity,
            Description, RaisedAt}) ->
    #{
        incident_id => IncidentId,
        division_id => DivisionId,
        incident_title => IncidentTitle,
        severity => Severity,
        description => Description,
        raised_at => RaisedAt
    };
row_to_map([IncidentId, DivisionId, IncidentTitle, Severity,
            Description, RaisedAt]) ->
    row_to_map({IncidentId, DivisionId, IncidentTitle, Severity,
                Description, RaisedAt}).
