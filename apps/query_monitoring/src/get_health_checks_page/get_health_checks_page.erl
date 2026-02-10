%%% @doc Query: list health checks for a division with pagination.
-module(get_health_checks_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT check_id, division_id, check_name, check_type, "
          "endpoint, interval_ms, registered_at, "
          "last_status, last_latency_ms, last_checked_at "
          "FROM health_checks WHERE division_id = ?1 "
          "ORDER BY registered_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_monitoring_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({CheckId, DivisionId, CheckName, CheckType,
            Endpoint, IntervalMs, RegisteredAt,
            LastStatus, LastLatencyMs, LastCheckedAt}) ->
    #{
        check_id => CheckId,
        division_id => DivisionId,
        check_name => CheckName,
        check_type => CheckType,
        endpoint => Endpoint,
        interval_ms => IntervalMs,
        registered_at => RegisteredAt,
        last_status => LastStatus,
        last_latency_ms => LastLatencyMs,
        last_checked_at => LastCheckedAt
    };
row_to_map([CheckId, DivisionId, CheckName, CheckType,
            Endpoint, IntervalMs, RegisteredAt,
            LastStatus, LastLatencyMs, LastCheckedAt]) ->
    row_to_map({CheckId, DivisionId, CheckName, CheckType,
                Endpoint, IntervalMs, RegisteredAt,
                LastStatus, LastLatencyMs, LastCheckedAt}).
