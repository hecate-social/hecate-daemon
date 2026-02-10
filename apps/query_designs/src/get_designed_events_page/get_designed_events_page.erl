%%% @doc Query: list designed events for a division with pagination.
-module(get_designed_events_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT event_id, division_id, event_name, aggregate_name, "
          "payload_fields, description, designed_by, designed_at "
          "FROM designed_events WHERE division_id = ?1 "
          "ORDER BY designed_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_designs_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({EventId, DivisionId, EventName, AggregateName,
            PayloadFieldsJson, Description, DesignedBy, DesignedAt}) ->
    PayloadFields = decode_json_field(PayloadFieldsJson),
    #{
        event_id => EventId,
        division_id => DivisionId,
        event_name => EventName,
        aggregate_name => AggregateName,
        payload_fields => PayloadFields,
        description => Description,
        designed_by => DesignedBy,
        designed_at => DesignedAt
    };
row_to_map([EventId, DivisionId, EventName, AggregateName,
            PayloadFieldsJson, Description, DesignedBy, DesignedAt]) ->
    row_to_map({EventId, DivisionId, EventName, AggregateName,
                PayloadFieldsJson, Description, DesignedBy, DesignedAt}).

decode_json_field(null) -> null;
decode_json_field(Val) when is_binary(Val) -> json:decode(Val);
decode_json_field(Val) -> Val.
