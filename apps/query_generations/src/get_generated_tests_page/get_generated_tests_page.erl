%%% @doc Query: list generated tests for a division with pagination.
-module(get_generated_tests_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    DivisionId = maps:get(division_id, Filters),
    Limit = maps:get(limit, Filters, 50),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT test_id, division_id, test_name, test_type, module_name, "
          "file_path, content, description, generated_by, generated_at "
          "FROM generated_tests WHERE division_id = ?1 "
          "ORDER BY generated_at DESC "
          "LIMIT ?2 OFFSET ?3",
    case query_generations_store:query(Sql, [DivisionId, Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({TestId, DivisionId, TestName, TestType, ModuleName,
            FilePath, Content, Description, GeneratedBy, GeneratedAt}) ->
    #{
        test_id => TestId,
        division_id => DivisionId,
        test_name => TestName,
        test_type => TestType,
        module_name => ModuleName,
        file_path => FilePath,
        content => Content,
        description => Description,
        generated_by => GeneratedBy,
        generated_at => GeneratedAt
    };
row_to_map([TestId, DivisionId, TestName, TestType, ModuleName,
            FilePath, Content, Description, GeneratedBy, GeneratedAt]) ->
    row_to_map({TestId, DivisionId, TestName, TestType, ModuleName,
                FilePath, Content, Description, GeneratedBy, GeneratedAt}).
