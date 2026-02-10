%%% @doc Query: list planned dependencies for a division with pagination.
-module(get_planned_dependencies_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT dependency_id, division_id, from_desk, to_desk, "
          "dependency_type, description, planned_by, planned_at "
          "FROM planned_dependencies WHERE division_id = ?1 "
          "ORDER BY planned_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_plans_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({DependencyId, DivisionId, FromDesk, ToDesk,
            DependencyType, Description, PlannedBy, PlannedAt}) ->
    #{
        dependency_id => DependencyId,
        division_id => DivisionId,
        from_desk => FromDesk,
        to_desk => ToDesk,
        dependency_type => DependencyType,
        description => Description,
        planned_by => PlannedBy,
        planned_at => PlannedAt
    };
row_to_map([DependencyId, DivisionId, FromDesk, ToDesk,
            DependencyType, Description, PlannedBy, PlannedAt]) ->
    row_to_map({DependencyId, DivisionId, FromDesk, ToDesk,
                DependencyType, Description, PlannedBy, PlannedAt}).
