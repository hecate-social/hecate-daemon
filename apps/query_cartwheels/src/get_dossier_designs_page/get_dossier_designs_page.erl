%%% @doc Query: list dossier designs for a project
-module(get_dossier_designs_page).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(#{cartwheel_id := CartwheelId} = Filters) ->
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    Sql = "SELECT dossier_id, cartwheel_id, dossier_name, stream_pattern, "
          "description, defined_at "
          "FROM dossier_designs WHERE cartwheel_id = ?1"
          " ORDER BY defined_at DESC"
          " LIMIT ?2"
          " OFFSET ?3",

    case query_cartwheels_store:query(Sql, [CartwheelId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

row_to_map({DossierId, CartwheelId, DossierName, StreamPattern,
            Description, DefinedAt}) ->
    #{
        dossier_id => DossierId,
        cartwheel_id => CartwheelId,
        dossier_name => DossierName,
        stream_pattern => StreamPattern,
        description => Description,
        defined_at => DefinedAt
    }.
