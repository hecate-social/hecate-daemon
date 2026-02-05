%%% @doc Query: list spoke inventory for a project with optional dossier filter
-module(list_spoke_inventory).

-export([execute/1]).

-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(#{project_id := ProjectId} = Filters) ->
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),

    {Sql, Params} = build_query(ProjectId, Filters, Limit, Offset),

    case query_alc_store:query(Sql, Params) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal

build_query(ProjectId, Filters, Limit, Offset) ->
    case maps:get(dossier_id, Filters, undefined) of
        undefined ->
            Sql = "SELECT spoke_id, project_id, spoke_name, spoke_type, "
                  "priority, dossier_id, description, inventoried_at "
                  "FROM spoke_inventory WHERE project_id = ?1"
                  " ORDER BY inventoried_at DESC"
                  " LIMIT ?2"
                  " OFFSET ?3",
            {Sql, [ProjectId, Limit, Offset]};
        DossierId ->
            Sql = "SELECT spoke_id, project_id, spoke_name, spoke_type, "
                  "priority, dossier_id, description, inventoried_at "
                  "FROM spoke_inventory WHERE project_id = ?1 AND dossier_id = ?2"
                  " ORDER BY inventoried_at DESC"
                  " LIMIT ?3"
                  " OFFSET ?4",
            {Sql, [ProjectId, DossierId, Limit, Offset]}
    end.

row_to_map({SpokeId, ProjectId, SpokeName, SpokeType,
            Priority, DossierId, Description, InventoriedAt}) ->
    #{
        spoke_id => SpokeId,
        project_id => ProjectId,
        spoke_name => SpokeName,
        spoke_type => SpokeType,
        priority => Priority,
        dossier_id => DossierId,
        description => Description,
        inventoried_at => InventoriedAt
    }.
