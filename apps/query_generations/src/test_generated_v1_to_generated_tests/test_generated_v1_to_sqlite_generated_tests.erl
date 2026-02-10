%%% @doc Projection: test_generated_v1 -> generated_tests table
-module(test_generated_v1_to_sqlite_generated_tests).
-export([project/1]).

project(Event) ->
    TestId = get(test_id, Event),
    DivisionId = get(division_id, Event),
    TestName = get(test_name, Event),
    TestType = get(test_type, Event),
    ModuleName = get(module_name, Event),
    FilePath = get(file_path, Event),
    Content = get(content, Event),
    Description = get(description, Event),
    GeneratedBy = get(generated_by, Event),
    GeneratedAt = get(generated_at, Event),
    Sql = "INSERT OR REPLACE INTO generated_tests "
          "(test_id, division_id, test_name, test_type, module_name, file_path, "
          "content, description, generated_by, generated_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
    query_generations_store:execute(Sql, [TestId, DivisionId, TestName, TestType,
                                         ModuleName, FilePath, Content, Description,
                                         GeneratedBy, GeneratedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
