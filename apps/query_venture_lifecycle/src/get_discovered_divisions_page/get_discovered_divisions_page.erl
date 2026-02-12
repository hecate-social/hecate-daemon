%%% @doc Query: list discovered divisions for a venture with pagination.
-module(get_discovered_divisions_page).

-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    VentureId = maps:get(venture_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT division_id, venture_id, context_name, description, "
          "identified_by, discovered_at "
          "FROM discovered_divisions WHERE venture_id = ?1 "
          "ORDER BY discovered_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_venture_lifecycle_store:query(Sql, [VentureId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({DivisionId, VentureId, ContextName, Description,
            IdentifiedBy, DiscoveredAt}) ->
    #{
        division_id => DivisionId,
        venture_id => VentureId,
        context_name => ContextName,
        description => Description,
        identified_by => IdentifiedBy,
        discovered_at => DiscoveredAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).
