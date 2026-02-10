%%% @doc Query: list designed aggregates for a division with pagination.
-module(get_designed_aggregates_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT aggregate_id, division_id, aggregate_name, stream_pattern, "
          "status_flags, description, designed_by, designed_at "
          "FROM designed_aggregates WHERE division_id = ?1 "
          "ORDER BY designed_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_designs_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({AggregateId, DivisionId, AggregateName, StreamPattern,
            StatusFlagsJson, Description, DesignedBy, DesignedAt}) ->
    StatusFlags = decode_json_field(StatusFlagsJson),
    #{
        aggregate_id => AggregateId,
        division_id => DivisionId,
        aggregate_name => AggregateName,
        stream_pattern => StreamPattern,
        status_flags => StatusFlags,
        description => Description,
        designed_by => DesignedBy,
        designed_at => DesignedAt
    };
row_to_map([AggregateId, DivisionId, AggregateName, StreamPattern,
            StatusFlagsJson, Description, DesignedBy, DesignedAt]) ->
    row_to_map({AggregateId, DivisionId, AggregateName, StreamPattern,
                StatusFlagsJson, Description, DesignedBy, DesignedAt}).

decode_json_field(null) -> null;
decode_json_field(Val) when is_binary(Val) -> json:decode(Val);
decode_json_field(Val) -> Val.
