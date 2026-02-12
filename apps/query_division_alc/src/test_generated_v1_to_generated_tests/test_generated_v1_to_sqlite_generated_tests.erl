%%% @doc Projection: test_generated_v1 -> generated_tests table
-module(test_generated_v1_to_sqlite_generated_tests).
-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    TestName = get(test_name, Event),
    ModuleName = get(module_name, Event),
    Path = get(path, Event),
    GeneratedAt = get(generated_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, TestName]),
    Sql = "INSERT OR REPLACE INTO generated_tests "
          "(division_id, test_name, module_name, path, generated_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_division_alc_store:execute(Sql, [DivisionId, TestName, ModuleName,
                                           Path, GeneratedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
