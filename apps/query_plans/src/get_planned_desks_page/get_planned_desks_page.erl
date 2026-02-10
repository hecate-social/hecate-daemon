%%% @doc Query: list planned desks for a division with pagination.
-module(get_planned_desks_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT desk_id, division_id, desk_name, department, aggregate_name, "
          "description, priority, planned_by, planned_at "
          "FROM planned_desks WHERE division_id = ?1 "
          "ORDER BY planned_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_plans_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({DeskId, DivisionId, DeskName, Department, AggregateName,
            Description, Priority, PlannedBy, PlannedAt}) ->
    #{
        desk_id => DeskId,
        division_id => DivisionId,
        desk_name => DeskName,
        department => Department,
        aggregate_name => AggregateName,
        description => Description,
        priority => Priority,
        planned_by => PlannedBy,
        planned_at => PlannedAt
    };
row_to_map([DeskId, DivisionId, DeskName, Department, AggregateName,
            Description, Priority, PlannedBy, PlannedAt]) ->
    row_to_map({DeskId, DivisionId, DeskName, Department, AggregateName,
                Description, Priority, PlannedBy, PlannedAt}).
