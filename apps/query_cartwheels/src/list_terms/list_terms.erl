%%% @doc Query: list terms for a project
-module(list_terms).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(#{cartwheel_id := CartwheelId} = Filters) ->
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    Sql = "SELECT term_id, cartwheel_id, term, definition, defined_at "
          "FROM terms WHERE cartwheel_id = ?1"
          " ORDER BY term ASC"
          " LIMIT ?2"
          " OFFSET ?3",

    case query_cartwheels_store:query(Sql, [CartwheelId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

row_to_map({TermId, CartwheelId, Term, Definition, DefinedAt}) ->
    #{
        term_id => TermId,
        cartwheel_id => CartwheelId,
        term => Term,
        definition => Definition,
        defined_at => DefinedAt
    }.
