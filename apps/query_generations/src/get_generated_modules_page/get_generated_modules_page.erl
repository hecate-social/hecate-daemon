%%% @doc Query: list generated modules for a division with pagination.
-module(get_generated_modules_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT module_id, division_id, module_name, module_type, "
          "file_path, content, description, generated_by, generated_at "
          "FROM generated_modules WHERE division_id = ?1 "
          "ORDER BY generated_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_generations_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({ModuleId, DivisionId, ModuleName, ModuleType,
            FilePath, Content, Description, GeneratedBy, GeneratedAt}) ->
    #{
        module_id => ModuleId,
        division_id => DivisionId,
        module_name => ModuleName,
        module_type => ModuleType,
        file_path => FilePath,
        content => Content,
        description => Description,
        generated_by => GeneratedBy,
        generated_at => GeneratedAt
    };
row_to_map([ModuleId, DivisionId, ModuleName, ModuleType,
            FilePath, Content, Description, GeneratedBy, GeneratedAt]) ->
    row_to_map({ModuleId, DivisionId, ModuleName, ModuleType,
                FilePath, Content, Description, GeneratedBy, GeneratedAt}).
