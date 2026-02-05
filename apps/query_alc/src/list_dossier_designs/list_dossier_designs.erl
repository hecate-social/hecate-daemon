%%% @doc Query: list dossier designs for a project
-module(list_dossier_designs).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(#{project_id := ProjectId} = Filters) ->
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    Sql = "SELECT dossier_id, project_id, dossier_name, stream_pattern, "
          "description, defined_at "
          "FROM dossier_designs WHERE project_id = ?1"
          " ORDER BY defined_at DESC"
          " LIMIT ?2"
          " OFFSET ?3",

    case query_alc_store:query(Sql, [ProjectId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

row_to_map({DossierId, ProjectId, DossierName, StreamPattern,
            Description, DefinedAt}) ->
    #{
        dossier_id => DossierId,
        project_id => ProjectId,
        dossier_name => DossierName,
        stream_pattern => StreamPattern,
        description => Description,
        defined_at => DefinedAt
    }.
