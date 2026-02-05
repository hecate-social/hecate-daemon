%%% @doc Query: list spoke implementations for a project with optional spoke filter
-module(list_spoke_implementations).

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
    case maps:get(spoke_id, Filters, undefined) of
        undefined ->
            Sql = "SELECT implementation_id, project_id, spoke_id, "
                  "implementation_notes, implemented_at "
                  "FROM spoke_implementations WHERE project_id = ?1"
                  " ORDER BY implemented_at DESC"
                  " LIMIT ?2"
                  " OFFSET ?3",
            {Sql, [ProjectId, Limit, Offset]};
        SpokeId ->
            Sql = "SELECT implementation_id, project_id, spoke_id, "
                  "implementation_notes, implemented_at "
                  "FROM spoke_implementations WHERE project_id = ?1 AND spoke_id = ?2"
                  " ORDER BY implemented_at DESC"
                  " LIMIT ?3"
                  " OFFSET ?4",
            {Sql, [ProjectId, SpokeId, Limit, Offset]}
    end.

row_to_map({ImplementationId, ProjectId, SpokeId,
            ImplementationNotes, ImplementedAt}) ->
    #{
        implementation_id => ImplementationId,
        project_id => ProjectId,
        spoke_id => SpokeId,
        implementation_notes => ImplementationNotes,
        implemented_at => ImplementedAt
    }.
