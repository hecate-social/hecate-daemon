%%% @doc Projection: module_generated_v1 -> generated_modules table
-module(module_generated_v1_to_sqlite_generated_modules).
-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    ModuleName = get(module_name, Event),
    ModuleType = get(module_type, Event),
    Path = get(path, Event),
    GeneratedAt = get(generated_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, ModuleName]),
    Sql = "INSERT OR REPLACE INTO generated_modules "
          "(division_id, module_name, module_type, path, generated_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_division_alc_store:execute(Sql, [DivisionId, ModuleName, ModuleType,
                                           Path, GeneratedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
