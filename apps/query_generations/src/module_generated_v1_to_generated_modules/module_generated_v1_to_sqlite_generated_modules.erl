%%% @doc Projection: module_generated_v1 -> generated_modules table
-module(module_generated_v1_to_sqlite_generated_modules).
-export([project/1]).

project(Event) ->
    ModuleId = get(module_id, Event),
    DivisionId = get(division_id, Event),
    ModuleName = get(module_name, Event),
    ModuleType = get(module_type, Event),
    FilePath = get(file_path, Event),
    Content = get(content, Event),
    Description = get(description, Event),
    GeneratedBy = get(generated_by, Event),
    GeneratedAt = get(generated_at, Event),
    Sql = "INSERT OR REPLACE INTO generated_modules "
          "(module_id, division_id, module_name, module_type, file_path, "
          "content, description, generated_by, generated_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
    query_generations_store:execute(Sql, [ModuleId, DivisionId, ModuleName, ModuleType,
                                         FilePath, Content, Description,
                                         GeneratedBy, GeneratedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
